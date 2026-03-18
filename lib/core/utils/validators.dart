class Validators {
  Validators._();

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    final phoneRegex = RegExp(r'^\+?[\d\s\-()]{7,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  static String? age(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    final age = int.tryParse(value.trim());
    if (age == null || age < 0 || age > 150) {
      return 'Please enter a valid age';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? medicalRecordNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    if (value.trim().length < 3) {
      return 'Medical record number is too short';
    }
    return null;
  }
}
