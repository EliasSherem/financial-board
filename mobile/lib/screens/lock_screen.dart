import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/biometric_service.dart';
import '../state/auth_store.dart';
import '../i18n.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _biometric = BiometricService();
  bool _submitting = false;
  bool _biometricChecked = false;
  bool _biometricSupported = false;
  bool _biometricEnrolled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    if (kIsWeb) {
      if (mounted) setState(() => _biometricChecked = true);
      return;
    }
    final availability = await _biometric.availability();
    if (!mounted) return;
    setState(() {
      _biometricSupported = availability.isSupported;
      _biometricEnrolled = availability.hasEnrollment;
      _biometricChecked = true;
    });
  }

  Future<void> _unlock() async {
    if (_submitting) return;
    final auth = context.read<AuthStore>();
    if (!auth.hasToken) return;
    final availability = await _biometric.availability();
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
      if (ok) {
        await auth.unlock();
      } else if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(I18n.tr(context, 'auth.biometricFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthStore>().logout(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.65);
    final canUnlock = _biometricChecked && _biometricSupported && _biometricEnrolled;
    final subtitle = !_biometricChecked
        ? I18n.t(context, 'auth.biometricReason')
        : !_biometricSupported
            ? I18n.t(context, 'auth.biometricUnavailable')
            : !_biometricEnrolled
                ? I18n.t(context, 'auth.biometricNotEnrolled')
                : I18n.t(context, 'auth.biometricReason');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 12,
                color: isDark ? Theme.of(context).colorScheme.surface : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF2563EB),
                          child: const Icon(Icons.fingerprint, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(height: 18),
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
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _submitting || !canUnlock ? null : _unlock,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(I18n.t(context, 'auth.signInBiometric')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _submitting ? null : _logout,
                        child: Text(I18n.t(context, 'menu.logout')),
                      ),
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
}
