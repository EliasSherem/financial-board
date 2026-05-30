import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/auth_store.dart';
import '../ui/finsight_ui.dart';

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
      if (_new.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.tr(context, 'error.passwordMin6'))),
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
      // Optional: call server to change password. Not implemented in API yet.
    }

    setState(() => _saving = true);
    try {
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
      backgroundColor: FSColors.background(context),
      appBar: AppBar(
        title: Text(I18n.t(context, 'title.updateProfile')),
        backgroundColor: FSColors.background(context),
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          FSSpacing.lg,
          FSSpacing.lg,
          FSSpacing.lg,
          FSSpacing.xxl,
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileSection(
                title: I18n.t(context, 'nav.account'),
                icon: Icons.person_outline,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: FSForm.textFieldDecoration(
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
                    const SizedBox(height: FSSpacing.md),
                    TextFormField(
                      controller: _email,
                      decoration: FSForm.textFieldDecoration(
                        context,
                        labelText: I18n.t(context, 'profile.email'),
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FSSpacing.lg),
              _ProfileSection(
                title: I18n.t(context, 'profile.changePassword'),
                icon: Icons.lock_outline,
                child: Column(
                  children: [
                    TextField(
                      controller: _current,
                      obscureText: true,
                      decoration: FSForm.textFieldDecoration(
                        context,
                        labelText: I18n.t(context, 'profile.currentPassword'),
                        prefixIcon: const Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: FSSpacing.md),
                    TextField(
                      controller: _new,
                      obscureText: true,
                      decoration: FSForm.textFieldDecoration(
                        context,
                        labelText: I18n.t(context, 'profile.newPassword'),
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                      ),
                    ),
                    const SizedBox(height: FSSpacing.md),
                    TextField(
                      controller: _confirm,
                      obscureText: true,
                      decoration: FSForm.textFieldDecoration(
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
              const SizedBox(height: FSSpacing.lg),
              _ProfileSection(
                title: I18n.t(context, 'profile.subscription'),
                icon: Icons.workspace_premium_outlined,
                trailing:
                    isPro
                        ? const FSStatusBadge(
                          label: 'Pro',
                          variant: FSStatusBadgeVariant.success,
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
                        color: FSColors.mutedText(context),
                        height: 1.35,
                      ),
                    ),
                    if (isPro) ...[
                      const SizedBox(height: FSSpacing.md),
                      FSButton(
                        label: I18n.t(
                          context,
                          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                              ? 'label.manageInAppStore'
                              : 'label.manageInPlay',
                        ),
                        icon: Icons.open_in_new,
                        variant: FSButtonVariant.outline,
                        fullWidth: true,
                        onPressed: _openSubscriptionManagement,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: FSSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: FSButton(
                      label: I18n.t(context, 'label.cancel'),
                      variant: FSButtonVariant.outline,
                      onPressed: _saving ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: FSSpacing.md),
                  Expanded(
                    child: FSButton(
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
    return FSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FSColors.intentContainer(context, FSIntent.primary),
                  borderRadius: BorderRadius.circular(FSRadius.md),
                  border: Border.all(
                    color: FSColors.intentBorder(context, FSIntent.primary),
                  ),
                ),
                child: Icon(icon, color: FSColors.primary, size: 20),
              ),
              const SizedBox(width: FSSpacing.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: FSSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: FSSpacing.lg),
          child,
        ],
      ),
    );
  }
}
