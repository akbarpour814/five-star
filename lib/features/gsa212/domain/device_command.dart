import 'package:equatable/equatable.dart';

class DeviceCommand extends Equatable {
  const DeviceCommand({required this.title, required this.body, required this.maskedBody, this.configPatch = const {}});

  final String title;

  /// Exact SMS text sent to the device.
  final String body;

  /// Same as [body] with passwords hidden; safe to store and display.
  final String maskedBody;

  /// Settings this command applies; remembered locally to prefill forms.
  final Map<String, Object?> configPatch;

  @override
  List<Object?> get props => [title, body, maskedBody, configPatch];
}

/// Four-zone access code: left digit is zone 1, right digit is zone 4.
class ZoneMask extends Equatable {
  const ZoneMask(this.zones);

  factory ZoneMask.parse(String code) => ZoneMask([for (var i = 0; i < 4; i++) i < code.length && code[i] == '1']);

  static const none = ZoneMask([false, false, false, false]);

  final List<bool> zones;

  bool get isEmpty => !zones.contains(true);

  String get code => zones.map((z) => z ? '1' : '0').join();

  List<int> get selected => [
    for (var i = 0; i < 4; i++)
      if (zones[i]) i + 1,
  ];

  ZoneMask toggle(int zone) {
    final next = [...zones];
    next[zone - 1] = !next[zone - 1];
    return ZoneMask(next);
  }

  @override
  List<Object?> get props => [code];
}

enum ZoneType {
  normal(0, 'معمولی'),
  always(1, '۲۴ ساعته'),
  delayed(2, 'تاخیری');

  const ZoneType(this.code, this.label);
  final int code;
  final String label;
}

enum SoundMode {
  speakerAndPiezo(0, 'بلندگو و پیزو فعال'),
  piezoOnly(1, 'بلندگو غیرفعال، پیزو فعال'),
  silent(2, 'بلندگو و پیزو غیرفعال');

  const SoundMode(this.code, this.label);
  final int code;
  final String label;
}
