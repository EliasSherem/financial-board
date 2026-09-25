import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../lang_store.dart';
import '../liquid_glass/liquid_glass.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../state/auth_store.dart';

String recoveryText(BuildContext context, String en, String es) =>
    context.read<LangStore>().lang == 'es' ? es : en;

/// Only the existing app scheme is accepted. HTTPS email links retain a web fallback.
String? recoveryTokenFromUri(Uri uri) {
  final isAppLink =
      uri.scheme == 'financialboard' &&
      (uri.host == 'reset-password' || uri.path == '/reset-password');
  final isRoute = uri.scheme.isEmpty && uri.path == '/reset-password';
  if (!isAppLink && !isRoute) return null;
  try {
    final fragment = Uri.splitQueryString(uri.fragment);
    final token = fragment['token'] ?? uri.queryParameters['token'];
    return token != null && RegExp(r'^[A-Za-z0-9_-]{43,256}$').hasMatch(token)
        ? token
        : null;
  } on FormatException {
    return null;
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  int _remaining = 0;
  String? _error;
  Timer? _cooldown;

  @override
  void dispose() {
    _cooldown?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldown?.cancel();
    _remaining = seconds.clamp(1, 3600);
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    if (_busy || _remaining > 0 || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final seconds = await AuthService(
        ApiClient(),
      ).forgotPassword(_email.text, context.read<LangStore>().lang);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _startCooldown(seconds);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 429) _startCooldown(e.retryAfterSeconds ?? 60);
        _error = recoveryText(
          context,
          'Please wait and try again. Check your connection if the problem continues.',
          'Espera y vuelve a intentarlo. Comprueba tu conexión si el problema continúa.',
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _error = recoveryText(
              context,
              'Unable to connect. Please try again.',
              'No se pudo conectar. Vuelve a intentarlo.',
            ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LangStore>();
    String l(String en, String es) => recoveryText(context, en, es);
    return _RecoveryShell(
      title: l('Reset your password', 'Recupera tu contraseña'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l(
                'Enter your account email to receive a secure recovery link.',
                'Escribe el correo de tu cuenta para recibir un enlace seguro.',
              ),
            ),
            const SizedBox(height: LGSpacing.lg),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              enabled: !_busy && _remaining == 0,
              decoration: LGForm.solidInputDecoration(
                context,
                labelText: l('Email', 'Correo'),
              ),
              validator:
                  (value) =>
                      value == null ||
                              !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value.trim())
                          ? l(
                            'Enter a valid email.',
                            'Escribe un correo válido.',
                          )
                          : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_sent) ...[
              const SizedBox(height: LGSpacing.lg),
              Semantics(
                liveRegion: true,
                child: Text(
                  l(
                    'If the email can receive recovery messages, a link is on its way. Check spam too. If you use a sign-in provider, recover your account with that provider. The link can also be completed in your browser on another device.',
                    'Si el correo puede recibir mensajes de recuperación, recibirás un enlace. Revisa también spam. Si usas un proveedor de acceso, recupera tu cuenta con ese proveedor. También puedes terminar en el navegador de otro dispositivo.',
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: LGSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(color: LGColors.danger),
                ),
              ),
            ],
            const SizedBox(height: LGSpacing.lg),
            LGButton(
              label:
                  _remaining > 0
                      ? l(
                        'Resend in ${_remaining}s',
                        'Reenviar en ${_remaining}s',
                      )
                      : _sent
                      ? l('Resend link', 'Reenviar enlace')
                      : l('Send recovery link', 'Enviar enlace'),
              fullWidth: true,
              loading: _busy,
              onPressed: _busy || _remaining > 0 ? null : _submit,
            ),
            const SizedBox(height: LGSpacing.md),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Text(l('Back to sign in', 'Volver a iniciar sesión')),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});
  final String? token;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late String? _token = widget.token;
  bool _busy = false;
  bool _done = false;
  bool _invalid = false;
  String? _invalidReason;
  String? _error;

  @override
  void dispose() {
    _token = null;
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _token == null || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService(ApiClient()).resetPassword(
        token: _token!,
        password: _password.text,
        confirmation: _confirmation.text,
        language: context.read<LangStore>().lang,
      );
      _token = null;
      _password.clear();
      _confirmation.clear();
      if (!mounted) return;
      await context.read<AuthStore>().logout(force: true);
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _invalid = e.code == 'INVALID_OR_EXPIRED_LINK';
        _invalidReason = e.reason;
        _error =
            e.code == 'PASSWORD_INVALID'
                ? recoveryText(
                  context,
                  'Use at least 6 characters and matching passwords.',
                  'Usa al menos 6 caracteres y contraseñas iguales.',
                )
                : recoveryText(
                  context,
                  'Unable to reset the password. Please try again.',
                  'No se pudo restablecer la contraseña. Vuelve a intentarlo.',
                );
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = recoveryText(
                context,
                'Unable to connect. Please try again.',
                'No se pudo conectar. Vuelve a intentarlo.',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LangStore>();
    String l(String en, String es) => recoveryText(context, en, es);
    final invalid = _invalid || (!_done && _token == null);
    return _RecoveryShell(
      title:
          _done
              ? l('Password updated', 'Contraseña actualizada')
              : invalid
              ? l('Link unavailable', 'Enlace no disponible')
              : l('Choose a new password', 'Elige una nueva contraseña'),
      child:
          _done
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l(
                        'Your password has changed. Sign in again on your devices. Your data and subscriptions are preserved.',
                        'Tu contraseña ha cambiado. Vuelve a iniciar sesión en tus dispositivos. Tus datos y suscripciones se conservan.',
                      ),
                    ),
                  ),
                  const SizedBox(height: LGSpacing.lg),
                  LGButton(
                    label: l('Back to sign in', 'Volver a iniciar sesión'),
                    fullWidth: true,
                    onPressed:
                        () => Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ],
              )
              : invalid
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l(
                      _invalidReason == 'used'
                          ? 'This link has already been used. Request a new link.'
                          : _invalidReason == 'expired'
                          ? 'This link has expired. Request a new link.'
                          : 'This link is invalid. Request a new link.',
                      _invalidReason == 'used'
                          ? 'Este enlace ya se usó. Solicita otro enlace.'
                          : _invalidReason == 'expired'
                          ? 'Este enlace caducó. Solicita otro enlace.'
                          : 'Este enlace no es válido. Solicita otro enlace.',
                    ),
                  ),
                  const SizedBox(height: LGSpacing.lg),
                  LGButton(
                    label: l('Request another link', 'Solicitar otro enlace'),
                    fullWidth: true,
                    onPressed:
                        () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: '/forgot-password',
                            ),
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                  ),
                ],
              )
              : Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      enabled: !_busy,
                      decoration: LGForm.solidInputDecoration(
                        context,
                        labelText: l('New password', 'Nueva contraseña'),
                      ),
                      validator:
                          (v) =>
                              v == null ||
                                      v.length < 6 ||
                                      utf8.encode(v).length > 72
                                  ? l(
                                    'At least 6 characters, maximum 72 bytes.',
                                    'Al menos 6 caracteres, máximo 72 bytes.',
                                  )
                                  : null,
                    ),
                    const SizedBox(height: LGSpacing.md),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      enabled: !_busy,
                      decoration: LGForm.solidInputDecoration(
                        context,
                        labelText: l(
                          'Confirm password',
                          'Confirmar contraseña',
                        ),
                      ),
                      validator:
                          (v) =>
                              v != _password.text
                                  ? l(
                                    'Passwords must match.',
                                    'Las contraseñas deben coincidir.',
                                  )
                                  : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: LGSpacing.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: const TextStyle(color: LGColors.danger),
                        ),
                      ),
                    ],
                    const SizedBox(height: LGSpacing.lg),
                    LGButton(
                      label: l('Update password', 'Actualizar contraseña'),
                      fullWidth: true,
                      loading: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                  ],
                ),
              ),
    );
  }
}

class _RecoveryShell extends StatelessWidget {
  const _RecoveryShell({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FinSight')),
    body: LGBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LGSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: LGGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: LGSpacing.lg),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
