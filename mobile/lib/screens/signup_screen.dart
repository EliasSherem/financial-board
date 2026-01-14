import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../state/auth_store.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/links.dart';
import 'package:flutter/gestures.dart';
import '../i18n.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        final api = ApiClient();
        final authSvc = AuthService(api);
        final token = await authSvc.signup(
          username: usernameCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text,
        );
        await context.read<AuthStore>().setToken(token);
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

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
                    key: formKey,
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
                              child: SvgPicture.asset('assets/finsight-icon.svg', width: 28, height: 28),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          I18n.t(context, 'auth.createAccount'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          I18n.t(context, 'auth.signupSubtitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
                        ),
                        const SizedBox(height: 22),
                        Text(I18n.t(context, 'auth.username'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: usernameCtrl,
                          validator: (v) => (v == null || v.isEmpty) ? I18n.t(context, 'validation.required') : null,
                          decoration: inputDec(context, I18n.t(context, 'auth.enterUsername')),
                        ),
                        const SizedBox(height: 14),
                        Text(I18n.t(context, 'auth.email'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: emailCtrl,
                          validator: (v) => (v == null || !v.contains('@')) ? I18n.t(context, 'auth.validEmailRequired') : null,
                          decoration: inputDec(context, I18n.t(context, 'auth.emailPlaceholder')),
                        ),
                        const SizedBox(height: 14),
                        Text(I18n.t(context, 'auth.password'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: true,
                          validator: (v) => (v == null || v.length < 6) ? I18n.t(context, 'auth.minimum6') : null,
                          decoration: inputDec(context, I18n.t(context, 'auth.minimum6')),
                        ),
                        const SizedBox(height: 14),
                        Text(I18n.t(context, 'auth.confirmPassword'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: confirmCtrl,
                          obscureText: true,
                          validator: (v) => (v != passwordCtrl.text) ? I18n.t(context, 'auth.passwordsNoMatch') : null,
                          decoration: inputDec(context, I18n.t(context, 'auth.reenterPassword')),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: submit,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(I18n.t(context, 'auth.createAccount')),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(I18n.t(context, 'auth.alreadyHave'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
                            icon: const Icon(Icons.arrow_back),
                            label: Text(I18n.t(context, 'auth.backToLogin')),
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF4F5D75)),
                            children: [
                              TextSpan(text: I18n.t(context, 'legal.signupPrefix')),
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
