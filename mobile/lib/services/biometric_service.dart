import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAvailability {
  const BiometricAvailability({
    required this.isSupported,
    required this.hasEnrollment,
  });

  final bool isSupported;
  final bool hasEnrollment;

  bool get isAvailable => isSupported && hasEnrollment;
}

class BiometricService {
  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<BiometricAvailability> availability() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        return const BiometricAvailability(isSupported: false, hasEnrollment: false);
      }
      final enrolled = await _auth.getAvailableBiometrics();
      return BiometricAvailability(
        isSupported: true,
        hasEnrollment: enrolled.isNotEmpty,
      );
    } on PlatformException {
      return const BiometricAvailability(isSupported: false, hasEnrollment: false);
    }
  }

  Future<bool> isAvailable() async {
    final status = await availability();
    return status.isAvailable;
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth
          .authenticate(
            localizedReason: reason,
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
              useErrorDialogs: true,
            ),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () async {
              await _auth.stopAuthentication();
              return false;
            },
          );
    } on PlatformException {
      return false;
    }
  }
}
