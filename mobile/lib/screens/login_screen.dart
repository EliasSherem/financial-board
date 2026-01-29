import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/links.dart';
import 'package:flutter/gestures.dart';
import '../services/auth_service.dart';
import '../state/auth_store.dart';
import 'signup_screen.dart';
import '../i18n.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;

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
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }
    return raw;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.push(MaterialPageRoute(builder: (_) => const SigningInScreen()));
    try {
      final api = ApiClient();
      final authSvc = AuthService(api);
      final token = await authSvc.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await context.read<AuthStore>().setToken(token);
      if (navigator.canPop()) {
        navigator.pop();
      }
    } catch (e) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.65);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: isDark
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
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
                        // Title & subtitle
                        Text(
                          'FinSight',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          I18n.t(context, 'auth.signInSubtitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
                        ),
                        const SizedBox(height: 22),
                        // Username
                        Text(I18n.t(context, 'auth.username'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameCtrl,
                          validator: (v) => (v == null || v.isEmpty) ? I18n.t(context, 'validation.required') : null,
                          decoration: InputDecoration(
                            hintText: I18n.t(context, 'auth.enterUsername'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Password
                        Text(I18n.t(context, 'auth.password'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          validator: (v) => (v == null || v.isEmpty) ? I18n.t(context, 'validation.required') : null,
                          decoration: InputDecoration(
                            hintText: I18n.t(context, 'auth.enterPassword'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Sign In button
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: const Icon(Icons.login_rounded),
                            label: Text(I18n.t(context, 'auth.signIn')),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Divider with OR
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(I18n.t(context, 'auth.or'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Signup link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(I18n.t(context, 'auth.signupCta'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(I18n.t(context, 'auth.signupFree')),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Legal with links
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF4F5D75)),
                            children: [
                              TextSpan(text: I18n.t(context, 'legal.loginPrefix')),
                              TextSpan(
                                text: I18n.t(context, 'menu.terms'),
                                style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => openLink(context, 'https://finsight.com.mx/terms'),
                              ),
                              TextSpan(text: ' ${I18n.t(context, 'legal.and')} '),
                              TextSpan(
                                text: I18n.t(context, 'menu.privacy'),
                                style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => openLink(context, 'https://finsight.com.mx/privacy'),
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

class SigningInScreen extends StatelessWidget {
  const SigningInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async => false,
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
