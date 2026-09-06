extension StringExtensions on String {
  bool get isBlank => trim().isEmpty;

  String get capitalize {
    if (isBlank) {
      return this;
    }

    final normalized = trim();
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  String get toTitleCase {
    if (isBlank) {
      return this;
    }

    return trim()
        .split(RegExp(r'\s+'))
        .map((String word) => word.capitalize)
        .join(' ');
  }

  String get maskPhone {
    final digits = replaceAll(RegExp(r'\D'), '');
    if (digits.length < 5) {
      return this;
    }

    final prefix = digits.substring(0, digits.length - 5);
    return '${prefix}XXXXX';
  }

  String get initials {
    final words =
        trim().split(RegExp(r'\s+')).where((String e) => e.isNotEmpty);
    return words.take(2).map((String word) => word[0].toUpperCase()).join();
  }
}
