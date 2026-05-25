import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../state/auth_store.dart';
import 'login_screen.dart';
import '../utils/links.dart';
import 'package:flutter/gestures.dart';
import '../i18n.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _errorText(Object error) {
    final raw = error.toString();
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

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final authStore = context.read<AuthStore>();
    navigator.push(MaterialPageRoute(builder: (_) => const SigningInScreen()));
    Object? submitError;
    try {
      final api = ApiClient();
      final authSvc = AuthService(api);
      final token = await authSvc.signup(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await authStore.setToken(token);
    } catch (e) {
      submitError = e;
    } finally {
      if (submitError == null) {
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
      } else {
        if (navigator.canPop()) {
          navigator.pop();
        }
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(_errorText(submitError))),
          );
          setState(() => _submitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration inputDec(BuildContext c, String hint) => InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(c).dividerColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: 0.65);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration:
            isDark
                ? null
                : const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF2F6FF), Color(0xFFEAF2FF)],
                  ),
                ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 12,
                color: isDark ? Theme.of(context).colorScheme.surface : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF2563EB),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: SvgPicture.asset(
                                'assets/finsight-icon.svg',
                                width: 28,
                                height: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          I18n.t(context, 'auth.createAccount'),
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          I18n.t(context, 'auth.signupSubtitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: muted),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          I18n.t(context, 'auth.username'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameCtrl,
                          validator:
                              (v) =>
                                  (v == null || v.isEmpty)
                                      ? I18n.t(context, 'validation.required')
                                      : null,
                          decoration: inputDec(
                            context,
                            I18n.t(context, 'auth.enterUsername'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          I18n.t(context, 'auth.email'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          validator:
                              (v) =>
                                  (v == null || !v.contains('@'))
                                      ? I18n.t(
                                        context,
                                        'auth.validEmailRequired',
                                      )
                                      : null,
                          decoration: inputDec(
                            context,
                            I18n.t(context, 'auth.emailPlaceholder'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          I18n.t(context, 'auth.password'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          validator:
                              (v) =>
                                  (v == null || v.length < 6)
                                      ? I18n.t(context, 'auth.minimum6')
                                      : null,
                          decoration: inputDec(
                            context,
                            I18n.t(context, 'auth.minimum6'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          I18n.t(context, 'auth.confirmPassword'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          validator:
                              (v) =>
                                  (v != _passwordCtrl.text)
                                      ? I18n.t(context, 'auth.passwordsNoMatch')
                                      : null,
                          decoration: inputDec(
                            context,
                            I18n.t(context, 'auth.reenterPassword'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(I18n.t(context, 'auth.createAccount')),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              I18n.t(context, 'auth.alreadyHave'),
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(color: muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton.icon(
                            onPressed:
                                _submitting
                                    ? null
                                    : () =>
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (_) => const LoginScreen(),
                                          ),
                                        ),
                            icon: const Icon(Icons.arrow_back),
                            label: Text(I18n.t(context, 'auth.backToLogin')),
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF4F5D75)),
                            children: [
                              TextSpan(
                                text: I18n.t(context, 'legal.signupPrefix'),
                              ),
                              TextSpan(
                                text: I18n.t(context, 'menu.terms'),
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap =
                                          () => openLink(
                                            context,
                                            'https://finsight.com.mx/terms',
                                          ),
                              ),
                              TextSpan(
                                text: ' ${I18n.t(context, 'legal.and')} ',
                              ),
                              TextSpan(
                                text: I18n.t(context, 'menu.privacy'),
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap =
                                          () => openLink(
                                            context,
                                            'https://finsight.com.mx/privacy',
                                          ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
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
