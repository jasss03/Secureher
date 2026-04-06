class PhoneUtils {
  /// Normalize a phone number for India (+91) in a simple, robust way.
  /// - Strips spaces, dashes, parentheses
  /// - If 10 digits => prefixes +91
  /// - If starts with 0 and 11 digits => drop 0, prefix +91
  /// - If starts with 91 and 12 digits => prefix +
  /// - If already starts with +91 => leave as-is
  static String normalizeIndianNumber(String input) {
    var s = input.trim().replaceAll(RegExp(r'[^0-9+]'), '');

    // Already in +91XXXXXXXXXX
    if (s.startsWith('+91') && s.length == 13) return s;

    // If starts with + and some country code, accept as-is
    if (s.startsWith('+')) return s;

    // 91XXXXXXXXXX -> +91XXXXXXXXXX
    if (s.startsWith('91') && s.length == 12) return '+$s';

    // 0XXXXXXXXXX -> +91XXXXXXXXXX
    if (s.startsWith('0') && s.length == 11) return '+91${s.substring(1)}';

    // XXXXXXXXXX (10 digits) -> +91XXXXXXXXXX
    if (s.length == 10) return '+91$s';

    // Fallback: default to +91 prefix if missing
    if (!s.startsWith('+')) return '+91$s';

    return s;
  }
}
