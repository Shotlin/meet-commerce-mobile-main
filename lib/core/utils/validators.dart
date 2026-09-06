class Validators {
  Validators._();

  static final RegExp _phoneRegex = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _pincodeRegex = RegExp(r'^\d{6}$');
  static final RegExp _otpRegex = RegExp(r'^\d{6}$');

  static String? validatePhone(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (normalized.isEmpty) {
      return 'Phone number is required.';
    }
    if (!_phoneRegex.hasMatch(normalized)) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    return null;
  }

  static String? validatePincode(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Pincode is required.';
    }
    if (!_pincodeRegex.hasMatch(normalized)) {
      return 'Enter a valid 6-digit pincode.';
    }
    return null;
  }

  static String? validateOtp(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'OTP is required.';
    }
    if (!_otpRegex.hasMatch(normalized)) {
      return 'OTP must be 6 digits.';
    }
    return null;
  }
}
