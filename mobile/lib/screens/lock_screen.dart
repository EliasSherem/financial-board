import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/biometric_service.dart';
import '../state/auth_store.dart';
import '../i18n.dart';
import '../ui/finsight_ui.dart';

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
      final failedMessage = I18n.tr(context, 'auth.biometricFailed');
      final ok = await _biometric.authenticate(
        reason: I18n.tr(context, 'auth.biometricReason'),
      );
      if (!mounted) return;
      if (ok) {
        await auth.unlock();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(failedMessage)));
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
    final theme = Theme.of(context);
    final canUnlock =
        _biometricChecked && _biometricSupported && _biometricEnrolled;
    final subtitle =
        !_biometricChecked
            ? I18n.t(context, 'auth.biometricReason')
            : !_biometricSupported
            ? I18n.t(context, 'auth.biometricUnavailable')
            : !_biometricEnrolled
            ? I18n.t(context, 'auth.biometricNotEnrolled')
            : I18n.t(context, 'auth.biometricReason');

    return Scaffold(
      backgroundColor: FSColors.background(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FSSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FSCard(
                variant: FSCardVariant.elevated,
                padding: const EdgeInsets.all(FSSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: FSColors.intentContainer(
                            context,
                            FSIntent.primary,
                          ),
                          borderRadius: BorderRadius.circular(FSRadius.xl),
                          border: Border.all(
                            color: FSColors.intentBorder(
                              context,
                              FSIntent.primary,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          color: FSColors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: FSSpacing.lg),
                    Text(
                      'FinSight',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: FSSpacing.sm),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: FSColors.mutedText(context),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: FSSpacing.xl),
                    FSButton(
                      label: I18n.t(context, 'auth.signInBiometric'),
                      icon: Icons.fingerprint,
                      loading: _submitting,
                      fullWidth: true,
                      onPressed: _submitting || !canUnlock ? null : _unlock,
                    ),
                    const SizedBox(height: FSSpacing.md),
                    FSButton(
                      label: I18n.t(context, 'menu.logout'),
                      variant: FSButtonVariant.outline,
                      fullWidth: true,
                      onPressed: _submitting ? null : _logout,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
