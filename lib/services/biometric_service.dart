import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  // Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  // Check if biometric is enrolled
  Future<bool> isBiometricEnrolled() async {
    try {
      final available = await _auth.canCheckBiometrics;
      if (!available) return false;
      
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Authenticate with biometric
  Future<bool> authenticate({
    String? reason,
    String? cancelButtonText,
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      final enrolled = await isBiometricEnrolled();
      if (!enrolled) return false;

      final authenticated = await _auth.authenticate(
        localizedReason: reason ?? 'Authenticate to access your vault',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: false,
          biometricOnly: true,
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      // Handle specific biometric errors
      switch (e.code) {
        case 'biometric_not_available':
          throw Exception('Biometric authentication not available');
        case 'biometric_not_enrolled':
          throw Exception('Biometric authentication not enrolled on your device');
        case 'biometric_not_recognized':
          throw Exception('Biometric authentication not recognized');
        case 'biometric_cancelled':
          throw Exception('Biometric authentication cancelled');
        case 'biometric_locked_out':
          throw Exception('Biometric authentication temporarily disabled');
        default:
          throw Exception('Biometric authentication failed');
      }
    } catch (e) {
      throw Exception('Biometric authentication failed');
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Check if device supports biometric
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }
}