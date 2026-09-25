import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/links.dart';
import 'package:flutter/gestures.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../state/auth_store.dart';
import 'signup_screen.dart';
import 'password_recovery_screen.dart';
import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _biometric = BiometricService();
  bool _submitting = false;
  bool _biometricAvailable = false;
  bool _biometricChecked = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _errorText(Object error) {
    final raw = error.toString();
    if (raw.contains('API error 401')) {
      return I18n.tr(context, 'auth.invalidCredentials');
    }
    const prefix = 'Exception: ';
    final normalized =
        raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
    if (normalized.contains('Unable to find ') ||
        normalized.contains('Unable to connect to ') ||
        normalized.contains('timed out')) {
      return I18n.tr(context, 'auth.unreachable');
    }
    return normalized;
  }

  Future<void> _checkBiometric() async {
    if (kIsWeb) {
      if (mounted) setState(() => _biometricChecked = true);
      return;
    }
    final availability = await _biometric.availability();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = availability.isAvailable;
      _biometricChecked = true;
    });
  }

  Future<void> _loginWithBiometrics() async {
    if (_submitting) return;
    final auth = context.read<AuthStore>();
    if (!auth.hasToken) return;
    final token = auth.token!;
    final availability = await _biometric.availability();
    if (!mounted) return;
    if (!availability.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.tr(context, 'auth.biometricUnavailable'))),
      );
      return;
    }
    if (!availability.hasEnrollment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.tr(context, 'auth.biometricNotEnrolled'))),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await _biometric.authenticate(
        reason: I18n.tr(context, 'auth.biometricReason'),
      );
      if (!mounted) return;
      if (ok) {
        await auth.unlock(expectedToken: token);
      } else if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(I18n.tr(context, 'auth.biometricFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.push(MaterialPageRoute(builder: (_) => const SigningInScreen()));
    Object? submitError;
    try {
      final api = ApiClient();
      final authSvc = AuthService(api);
      final token = await authSvc.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await context.read<AuthStore>().setToken(token);
    } catch (e) {
      submitError = e;
    } finally {
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      if (submitError != null && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(_errorText(submitError))),
        );
      }
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final canUseBiometric = _biometricChecked && _biometricAvailable;
    final showBiometric =
        !kIsWeb && auth.biometricEnabled && auth.hasToken && canUseBiometric;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LGBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: LGSpacing.lg,
              vertical: LGSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 460,
                minHeight:
                    MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical -
                    (LGSpacing.xl * 2),
              ),
              child: Center(
                child: LGGlassCard(
                  variant: LGCardVariant.hero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: LGSpacing.xl,
                    vertical: LGSpacing.xxl,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _AuthLogo(),
                        const SizedBox(height: LGSpacing.lg),
                        Text(
                          'FinSight',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: LGColors.textPrimary(context),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: LGSpacing.xs),
                        Text(
                          I18n.t(context, 'auth.signInSubtitle'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: LGColors.textSecondary(context),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: LGSpacing.xl),
                        TextFormField(
                          controller: _usernameCtrl,
                          validator:
                              (v) =>
                                  (v == null || v.isEmpty)
                                      ? I18n.t(context, 'validation.required')
                                      : null,
                          decoration: LGForm.solidInputDecoration(
                            context,
                            labelText: I18n.t(context, 'auth.username'),
                            hintText: I18n.t(context, 'auth.enterUsername'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: LGSpacing.md),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          validator:
                              (v) =>
                                  (v == null || v.isEmpty)
                                      ? I18n.t(context, 'validation.required')
                                      : null,
                          decoration: LGForm.solidInputDecoration(
                            context,
                            labelText: I18n.t(context, 'auth.password'),
                            hintText: I18n.t(context, 'auth.enterPassword'),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                _submitting
                                    ? null
                                    : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        settings: const RouteSettings(
                                          name: '/forgot-password',
                                        ),
                                        builder:
                                            (_) => const ForgotPasswordScreen(),
                                      ),
                                    ),
                            child: Text(
                              recoveryText(
                                context,
                                'Forgot password?',
                                '¿Olvidaste tu contraseña?',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: LGSpacing.lg),
                        LGButton(
                          label: I18n.t(context, 'auth.signIn'),
                          icon: Icons.login_rounded,
                          size: LGButtonSize.lg,
                          fullWidth: true,
                          loading: _submitting,
                          onPressed: _submitting ? null : _submit,
                        ),
                        if (showBiometric) ...[
                          const SizedBox(height: LGSpacing.md),
                          LGButton(
                            label: I18n.t(context, 'auth.signInBiometric'),
                            icon: Icons.fingerprint,
                            size: LGButtonSize.lg,
                            variant: LGButtonVariant.glass,
                            fullWidth: true,
                            onPressed:
                                _submitting ? null : _loginWithBiometrics,
                          ),
                        ],
                        const SizedBox(height: LGSpacing.lg),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: LGSpacing.sm,
                              ),
                              child: Text(
                                I18n.t(context, 'auth.or'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: LGColors.textSecondary(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: LGSpacing.md),
                        Text(
                          I18n.t(context, 'auth.signupCta'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: LGColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: LGSpacing.sm),
                        LGButton(
                          label: I18n.t(context, 'auth.signupFree'),
                          icon: Icons.person_add_alt_1_rounded,
                          size: LGButtonSize.md,
                          variant: LGButtonVariant.outline,
                          fullWidth: true,
                          onPressed:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              ),
                        ),
                        const SizedBox(height: LGSpacing.lg),
                        _AuthLegalText(prefixKey: 'legal.loginPrefix'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LGColors.primaryBlue,
          borderRadius: BorderRadius.circular(LGRadius.xl),
          boxShadow: LGShadows.floating(context),
        ),
        child: SvgPicture.asset(
          'assets/finsight-icon.svg',
          width: 34,
          height: 34,
        ),
      ),
    );
  }
}

class _AuthLegalText extends StatelessWidget {
  const _AuthLegalText({required this.prefixKey});

  final String prefixKey;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: LGColors.textSecondary(context),
          height: 1.35,
        ),
        children: [
          TextSpan(text: I18n.t(context, prefixKey)),
          TextSpan(
            text: I18n.t(context, 'menu.terms'),
            style: const TextStyle(
              color: LGColors.primaryBlue,
              fontWeight: FontWeight.w800,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap =
                      () => openLink(context, 'https://finsight.com.mx/terms'),
          ),
          TextSpan(text: ' ${I18n.t(context, 'legal.and')} '),
          TextSpan(
            text: I18n.t(context, 'menu.privacy'),
            style: const TextStyle(
              color: LGColors.primaryBlue,
              fontWeight: FontWeight.w800,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap =
                      () =>
                          openLink(context, 'https://finsight.com.mx/privacy'),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

class SigningInScreen extends StatelessWidget {
  const SigningInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                I18n.t(context, 'auth.signingIn'),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
