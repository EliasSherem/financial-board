import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/biometric_service.dart';
import '../state/auth_store.dart';
import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: LGSpacing.lg,
              vertical: LGSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: LGGlassCard(
                variant: LGCardVariant.hero,
                padding: const EdgeInsets.symmetric(
                  horizontal: LGSpacing.xl,
                  vertical: LGSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 68,
                        height: 68,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: LGColors.intentContainer(
                            context,
                            LGIntent.primary,
                          ),
                          borderRadius: BorderRadius.circular(LGRadius.xl),
                          border: Border.all(
                            color: LGColors.intentStroke(
                              context,
                              LGIntent.primary,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          color: LGColors.primaryBlue,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: LGSpacing.lg),
                    Text(
                      'FinSight',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: LGColors.textPrimary(context),
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: LGSpacing.sm),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: LGColors.textSecondary(context),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: LGSpacing.md),
                    Align(
                      alignment: Alignment.center,
                      child: LGStatusBadge(
                        label:
                            canUnlock
                                ? I18n.t(context, 'auth.signInBiometric')
                                : I18n.t(context, 'auth.biometricUnavailable'),
                        variant:
                            canUnlock
                                ? LGStatusBadgeVariant.info
                                : LGStatusBadgeVariant.neutral,
                        icon:
                            canUnlock
                                ? Icons.verified_user_outlined
                                : Icons.info_outline,
                      ),
                    ),
                    const SizedBox(height: LGSpacing.xl),
                    LGButton(
                      label: I18n.t(context, 'auth.signInBiometric'),
                      icon: Icons.fingerprint,
                      loading: _submitting,
                      fullWidth: true,
                      onPressed: _submitting || !canUnlock ? null : _unlock,
                    ),
                    const SizedBox(height: LGSpacing.md),
                    LGButton(
                      label: I18n.t(context, 'menu.logout'),
                      icon: Icons.logout,
                      variant: LGButtonVariant.outline,
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
