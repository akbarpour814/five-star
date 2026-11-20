abstract final class TextNormalizer {
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

  static String digitsToLatin(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final fa = _persianDigits.indexOf(char);
      final ar = _arabicDigits.indexOf(char);
      if (fa >= 0) {
        buffer.write(fa);
      } else if (ar >= 0) {
        buffer.write(ar);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static String toPersianDigits(Object input) {
    return input.toString().replaceAllMapped(RegExp('[0-9]'), (m) => _persianDigits[int.parse(m[0]!)]);
  }

  /// Unifies Arabic/Persian letter variants, digits and spacing so device replies
  /// can be matched regardless of the encoding the SIM module used.
  static String normalize(String input) {
    return digitsToLatin(input)
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('‌', ' ')
        .replaceAll('‏', '')
        .replaceAll('‎', '')
        .replaceAll('\r', '')
        .replaceAll(RegExp('[ \t]+'), ' ')
        .trim();
  }

  static String compact(String input) => normalize(input).replaceAll(RegExp(r'\s+'), '');
}
