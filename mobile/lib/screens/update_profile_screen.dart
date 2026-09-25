import '../lang_store.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/auth_store.dart';
import '../liquid_glass/liquid_glass.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import 'password_recovery_screen.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  // No in-app cancellation; we direct users to the store subscriptions page.

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final sp = await SharedPreferences.getInstance();
    Map<String, dynamic> user = {};
    try {
      final str = sp.getString('user') ?? '{}';
      user = (jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {}
    _name.text = (user['username'] as String?) ?? '';
    _email.text = (user['email'] as String?) ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_new.text.isNotEmpty) {
      if (_new.text.length < 6 || utf8.encode(_new.text).length > 72) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              recoveryText(
                context,
                'Use at least 6 characters, with a maximum of 72 UTF-8 bytes.',
                'Usa al menos 6 caracteres, con un máximo de 72 bytes UTF-8.',
              ),
            ),
          ),
        );
        return;
      }
      if (_new.text != _confirm.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.tr(context, 'error.passwordsDontMatch'))),
        );
        return;
      }
      if (_current.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.tr(context, 'error.currentPasswordRequired')),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (_new.text.isNotEmpty) {
        final auth = context.read<AuthStore>();
        final token = auth.token;
        await AuthService(ApiClient()..setToken(token)).changePassword(
          currentPassword: _current.text,
          password: _new.text,
          confirmation: _confirm.text,
          language: context.read<LangStore>().lang,
        );
        _current.clear();
        _new.clear();
        _confirm.clear();
        if (!mounted) return;
        await auth.logout(force: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              recoveryText(
                context,
                'Password changed. Sign in again.',
                'Contraseña actualizada. Vuelve a iniciar sesión.',
              ),
            ),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      final sp = await SharedPreferences.getInstance();
      Map<String, dynamic> user = {};
      try {
        final str = sp.getString('user') ?? '{}';
        user = (jsonDecode(str) as Map<String, dynamic>);
      } catch (_) {}
      user['username'] = _name.text.trim();
      user['email'] = _email.text.trim();
      await sp.setString('user', jsonEncode(user));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.tr(context, 'feedback.profileUpdated'))),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              recoveryText(
                context,
                'Unable to save. Check your current password and connection.',
                'No se pudo guardar. Comprueba tu contraseña actual y conexión.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSubscriptionManagement() async {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final uri = Uri.parse(
      isIos
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              I18n.tr(
                context,
                isIos ? 'error.unableOpenAppStore' : 'error.unableOpenPlay',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    final isPro = store.isProOrExempt;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            LGSpacing.lg,
            LGSpacing.lg,
            LGSpacing.lg,
            120,
          ),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LGPageHeader(
                  title: I18n.t(context, 'title.updateProfile'),
                  subtitle: I18n.t(context, 'profile.changePassword'),
                  leading: const _ProfileBackButton(),
                ),
                const SizedBox(height: LGSpacing.md),
                _ProfileSection(
                  title: I18n.t(context, 'nav.account'),
                  icon: Icons.person_outline,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: LGForm.solidInputDecoration(
                          context,
                          labelText: I18n.t(context, 'profile.username'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ), // web parity key name
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? I18n.t(context, 'validation.required')
                                    : null,
                      ),
                      const SizedBox(height: LGSpacing.md),
                      TextFormField(
                        controller: _email,
                        decoration: LGForm.solidInputDecoration(
                          context,
                          labelText: I18n.t(context, 'profile.email'),
                          prefixIcon: const Icon(Icons.mail_outline),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LGSpacing.lg),
                _ProfileSection(
                  title: I18n.t(context, 'profile.changePassword'),
                  icon: Icons.lock_outline,
                  child: Column(
                    children: [
                      TextField(
                        controller: _current,
                        obscureText: true,
                        decoration: LGForm.solidInputDecoration(
                          context,
                          labelText: I18n.t(context, 'profile.currentPassword'),
                          prefixIcon: const Icon(Icons.key_outlined),
                        ),
                      ),
                      const SizedBox(height: LGSpacing.md),
                      TextField(
                        controller: _new,
                        obscureText: true,
                        decoration: LGForm.solidInputDecoration(
                          context,
                          labelText: I18n.t(context, 'profile.newPassword'),
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                        ),
                      ),
                      const SizedBox(height: LGSpacing.md),
                      TextField(
                        controller: _confirm,
                        obscureText: true,
                        decoration: LGForm.solidInputDecoration(
                          context,
                          labelText: I18n.t(
                            context,
                            'profile.confirmNewPassword',
                          ),
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LGSpacing.lg),
                _ProfileSection(
                  title: I18n.t(context, 'profile.subscription'),
                  icon: Icons.workspace_premium_outlined,
                  trailing:
                      isPro
                          ? const LGStatusBadge(
                            label: 'Pro',
                            variant: LGStatusBadgeVariant.success,
                          )
                          : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isPro
                            ? I18n.t(context, 'profile.proPlanText')
                            : I18n.t(context, 'profile.freePlanText'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: LGColors.textSecondary(context),
                          height: 1.35,
                        ),
                      ),
                      if (isPro) ...[
                        const SizedBox(height: LGSpacing.md),
                        LGButton(
                          label: I18n.t(
                            context,
                            !kIsWeb &&
                                    defaultTargetPlatform == TargetPlatform.iOS
                                ? 'label.manageInAppStore'
                                : 'label.manageInPlay',
                          ),
                          icon: Icons.open_in_new,
                          variant: LGButtonVariant.outline,
                          fullWidth: true,
                          onPressed: _openSubscriptionManagement,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: LGSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: LGButton(
                        label: I18n.t(context, 'label.cancel'),
                        variant: LGButtonVariant.outline,
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: LGSpacing.md),
                    Expanded(
                      child: LGButton(
                        label:
                            _saving
                                ? I18n.t(context, 'label.updating')
                                : I18n.t(context, 'label.update'),
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBackButton extends StatelessWidget {
  const _ProfileBackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.pill),
        onTap: () => Navigator.maybePop(context),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LGColors.surfaceTinted(context),
            borderRadius: BorderRadius.circular(LGRadius.pill),
            border: Border.all(
              color: LGColors.alpha(LGColors.textSecondary(context), 0.18),
            ),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: LGColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LGSolidCard(
      variant: LGCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProfileIconBox(icon: icon),
              const SizedBox(width: LGSpacing.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: LGColors.textPrimary(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: LGSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: LGSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _ProfileIconBox extends StatelessWidget {
  const _ProfileIconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LGColors.intentContainer(context, LGIntent.primary),
        borderRadius: BorderRadius.circular(LGRadius.md),
        border: Border.all(
          color: LGColors.intentStroke(context, LGIntent.primary),
        ),
      ),
      child: Icon(icon, color: LGColors.primaryBlue, size: 20),
    );
  }
}
