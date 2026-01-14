import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';
import '../services/data_service.dart';
import '../i18n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/auth_store.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final DataService _data;
  late TextEditingController _name;
  late TextEditingController _email;
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  // No in-app cancellation; we direct users to Google Play subscriptions page

  @override
  void initState() {
    super.initState();
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    _data = DataService(api);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final sp = await SharedPreferences.getInstance();
    Map<String, dynamic> user = {};
    try {
      final str = sp.getString('user') ?? '{}';
      user = (jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {}
    _name = TextEditingController(text: (user['username'] as String?) ?? '');
    _email = TextEditingController(text: (user['email'] as String?) ?? '');
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_new.text.isNotEmpty) {
      if (_new.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.tr(context, 'error.passwordMin6'))));
        return;
      }
      if (_new.text != _confirm.text) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.tr(context, 'error.passwordsDontMatch'))));
        return;
      }
      if (_current.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.tr(context, 'error.currentPasswordRequired'))));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.tr(context, 'feedback.profileUpdated'))));
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPlaySubscriptions() async {
    final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.tr(context, 'error.unableOpenPlay'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    final isPro = store.isProOrExempt;
    return Scaffold(
      appBar: AppBar(title: Text(I18n.t(context, 'title.updateProfile'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: I18n.t(context, 'profile.username')), // web parity key name
                validator: (v) => (v==null || v.trim().isEmpty) ? I18n.t(context, 'validation.required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: InputDecoration(labelText: I18n.t(context, 'profile.email'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Text(I18n.t(context, 'profile.changePassword'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: _current, obscureText: true, decoration: InputDecoration(labelText: I18n.t(context, 'profile.currentPassword'), border: const OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _new, obscureText: true, decoration: InputDecoration(labelText: I18n.t(context, 'profile.newPassword'), border: const OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _confirm, obscureText: true, decoration: InputDecoration(labelText: I18n.t(context, 'profile.confirmNewPassword'), border: const OutlineInputBorder())),
              const SizedBox(height: 16),
              Text(I18n.t(context, 'profile.subscription'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(isPro ? I18n.t(context, 'profile.proPlanText') : I18n.t(context, 'profile.freePlanText')),
              if (isPro) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openPlaySubscriptions,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(I18n.t(context, 'label.manageInPlay')),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _saving ? null : ()=>Navigator.pop(context), child: Text(I18n.t(context, 'label.cancel'))),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _saving ? null : _save, child: _saving ? Text(I18n.t(context, 'label.updating')) : Text(I18n.t(context, 'label.update'))),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
