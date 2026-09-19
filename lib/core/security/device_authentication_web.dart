/// WebAuthn is not part of the verified Bakaloo backend contract. Browser
/// builds therefore skip this optional native-device gate; authenticated API
/// session checks remain server-authoritative.
class DeviceAuthentication {
  Future<bool> authenticateIfAvailable({
    required String reason,
    bool preferBiometrics = false,
    bool stickyAuth = true,
  }) async =>
      true;
}
