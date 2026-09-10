String? validateRequiredText(
  String? value, {
  required String label,
  int maxLength = 120,
}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter $label.';
  if (text.length > maxLength) {
    return '$label must be $maxLength characters or fewer.';
  }
  return null;
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  return valid ? null : 'Enter a valid email address.';
}

String? validateLoginPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Enter your password.';
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.length < 8) return 'Use at least 8 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
      !RegExp(r'\d').hasMatch(password)) {
    return 'Use a password with letters and numbers.';
  }
  return null;
}

String? validatePositiveNumber(String? value, {required String label}) {
  final number = double.tryParse(value?.trim() ?? '');
  if (number == null || !number.isFinite || number <= 0) {
    return 'Enter a valid $label above zero.';
  }
  return null;
}

String? validateNonNegativeNumber(String? value, {required String label}) {
  if (value == null || value.trim().isEmpty) return null;
  final number = double.tryParse(value.trim());
  if (number == null || !number.isFinite || number < 0) {
    return 'Enter a valid non-negative $label.';
  }
  return null;
}
