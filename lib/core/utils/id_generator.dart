import 'dart:math';

abstract final class IdGenerator {
  static final _random = Random();

  static String next() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';
}
