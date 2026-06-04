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
import '../liquid_glass/liquid_glass.dart';

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
                        const _SignupLogo(),
                        const SizedBox(height: LGSpacing.lg),
                        Text(
                          I18n.t(context, 'auth.createAccount'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: LGColors.textPrimary(context),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: LGSpacing.xs),
                        Text(
                          I18n.t(context, 'auth.signupSubtitle'),
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
                          controller: _emailCtrl,
                          validator:
                              (v) =>
                                  (v == null || !v.contains('@'))
                                      ? I18n.t(
                                        context,
                                        'auth.validEmailRequired',
                                      )
                                      : null,
                          decoration: LGForm.solidInputDecoration(
                            context,
                            labelText: I18n.t(context, 'auth.email'),
                            hintText: I18n.t(context, 'auth.emailPlaceholder'),
                            prefixIcon: const Icon(Icons.mail_outline),
                          ),
                        ),
                        const SizedBox(height: LGSpacing.md),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          validator:
                              (v) =>
                                  (v == null || v.length < 6)
                                      ? I18n.t(context, 'auth.minimum6')
                                      : null,
                          decoration: LGForm.solidInputDecoration(
                            context,
                            labelText: I18n.t(context, 'auth.password'),
                            hintText: I18n.t(context, 'auth.minimum6'),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: LGSpacing.md),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          validator:
                              (v) =>
                                  (v != _passwordCtrl.text)
                                      ? I18n.t(context, 'auth.passwordsNoMatch')
                                      : null,
                          decoration: LGForm.solidInputDecoration(
                            context,
                            labelText: I18n.t(context, 'auth.confirmPassword'),
                            hintText: I18n.t(context, 'auth.reenterPassword'),
                            prefixIcon: const Icon(Icons.verified_outlined),
                          ),
                        ),
                        const SizedBox(height: LGSpacing.lg),
                        LGButton(
                          label: I18n.t(context, 'auth.createAccount'),
                          icon: Icons.person_add_alt_1_rounded,
                          size: LGButtonSize.lg,
                          fullWidth: true,
                          loading: _submitting,
                          onPressed: _submitting ? null : _submit,
                        ),
                        const SizedBox(height: LGSpacing.lg),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: LGSpacing.sm,
                              ),
                              child: Text(
                                I18n.t(context, 'auth.alreadyHave'),
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
                        LGButton(
                          label: I18n.t(context, 'auth.backToLogin'),
                          icon: Icons.arrow_back_rounded,
                          size: LGButtonSize.md,
                          variant: LGButtonVariant.outline,
                          fullWidth: true,
                          onPressed:
                              _submitting
                                  ? null
                                  : () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  ),
                        ),
                        const SizedBox(height: LGSpacing.lg),
                        const _SignupLegalText(),
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

class _SignupLogo extends StatelessWidget {
  const _SignupLogo();

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

class _SignupLegalText extends StatelessWidget {
  const _SignupLegalText();

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
          TextSpan(text: I18n.t(context, 'legal.signupPrefix')),
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
