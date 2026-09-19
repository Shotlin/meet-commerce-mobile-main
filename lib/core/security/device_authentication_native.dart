import 'package:local_auth/local_auth.dart';

/// Optional device-auth gate for sensitive native screens. It never replaces
/// backend session authorization.
class DeviceAuthentication {
  DeviceAuthentication({LocalAuthentication? localAuthentication})
      : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> authenticateIfAvailable({
    required String reason,
    bool preferBiometrics = false,
    bool stickyAuth = true,
  }) async {
    final supported = await _localAuthentication.isDeviceSupported();
    if (!supported) {
      return true;
    }

    final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
    final availableBiometrics =
        await _localAuthentication.getAvailableBiometrics();
    final biometricOnly = preferBiometrics ||
        (canCheckBiometrics && availableBiometrics.isNotEmpty);

    return _localAuthentication.authenticate(
      localizedReason: reason,
      options: AuthenticationOptions(
        biometricOnly: biometricOnly,
        stickyAuth: stickyAuth,
        sensitiveTransaction: true,
      ),
    );
  }
}
