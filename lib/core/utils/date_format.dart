import 'text_normalizer.dart';

abstract final class AppDateFormat {
  static String time(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return TextNormalizer.toPersianDigits('$h:$m');
  }

  static String relative(DateTime value, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(value);
    if (diff.inSeconds < 60) return 'لحظاتی پیش';
    if (diff.inMinutes < 60) return '${TextNormalizer.toPersianDigits(diff.inMinutes)} دقیقه پیش';
    if (diff.inHours < 24) return '${TextNormalizer.toPersianDigits(diff.inHours)} ساعت پیش';
    if (diff.inDays < 30) return '${TextNormalizer.toPersianDigits(diff.inDays)} روز پیش';
    return TextNormalizer.toPersianDigits('${value.year}/${value.month}/${value.day}');
  }

  static String countdown(Duration value) {
    final m = value.inMinutes.toString().padLeft(2, '0');
    final s = (value.inSeconds % 60).toString().padLeft(2, '0');
    return TextNormalizer.toPersianDigits('$m:$s');
  }
}
