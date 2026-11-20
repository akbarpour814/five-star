import 'text_normalizer.dart';

abstract final class PhoneUtils {
  static final _mobile = RegExp(r'^09\d{9}$');
  static final _anyNumber = RegExp(r'^\d{4,15}$');

  /// Converts +98 / 0098 / 98 / bare 9xx forms to the local 09xxxxxxxxx form.
  static String normalize(String input) {
    var digits = TextNormalizer.digitsToLatin(input).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0098')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('98') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    } else if (digits.startsWith('9') && digits.length == 10) {
      digits = '0$digits';
    }
    return digits;
  }

  static bool isValidMobile(String input) => _mobile.hasMatch(normalize(input));

  static bool isValidAnyNumber(String input) => _anyNumber.hasMatch(normalize(input));

  /// Comparison key that ignores country-code formatting differences.
  static String matchKey(String input) {
    final digits = normalize(input);
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  static bool same(String a, String b) => matchKey(a) == matchKey(b);
}
