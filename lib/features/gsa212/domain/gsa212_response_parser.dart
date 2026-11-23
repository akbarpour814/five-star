import 'package:equatable/equatable.dart';

import '../../../core/utils/text_normalizer.dart';
import '../../devices/domain/entities/device_message.dart';
import '../../devices/domain/entities/device_status.dart';
import 'gsa212_commands.dart';

typedef StatusPatch = DeviceStatus Function(DeviceStatus status);

class ParsedResponse extends Equatable {
  const ParsedResponse({
    required this.title,
    this.detail,
    this.severity = MessageSeverity.success,
    this.patch,
    this.config = const {},
    this.recognized = true,
    this.output,
  });

  const ParsedResponse.unknown()
    : title = 'پیام دستگاه',
      detail = null,
      severity = MessageSeverity.info,
      patch = null,
      config = const {},
      recognized = false,
      output = null;

  final String title;
  final String? detail;
  final MessageSeverity severity;
  final StatusPatch? patch;
  final Map<String, Object?> config;
  final bool recognized;

  /// Set when the reply confirms a single output (1–4).
  final int? output;

  /// The device answers a momentary (pulse) command like a permanent one; the output is
  /// already off again, so log it as a pulse and keep it shown as off.
  ParsedResponse asMomentary() => ParsedResponse(
    title: 'خروجی ${TextNormalizer.toPersianDigits(output!)} به‌صورت لحظه‌ای فعال شد',
    detail: detail,
    severity: severity,
    patch: (s) => s.withOutput(output!, false),
    config: config,
    recognized: recognized,
    output: output,
  );

  @override
  List<Object?> get props => [title, detail, severity, config, recognized, output];
}

/// Interprets SMS replies of the GSA-212 following the code/answer table.
/// Matching runs on a whitespace-free normalized copy so spacing/letter variants don't matter.
class Gsa212ResponseParser {
  const Gsa212ResponseParser();

  static const _onOff = '(غیرفعال|فعال)';

  ParsedResponse parse(String raw) {
    final text = TextNormalizer.normalize(raw);
    final c = TextNormalizer.compact(raw);
    if (c.isEmpty) return const ParsedResponse.unknown();

    return _memories(text) ??
        _englishStatus(c.toUpperCase()) ??
        _status(text, c) ??
        _rules(c) ??
        _alerts(c) ??
        const ParsedResponse.unknown();
  }

  /// English status reply, e.g. `OUT 1: OFF , OUT 2: OFF , ... ,Device status:DISARM`.
  ParsedResponse? _englishStatus(String c) {
    final outputs = <bool?>[null, null, null, null];
    for (final m in RegExp(r'OUT(?:PUT)?([1-4]):?(ON|OFF)').allMatches(c)) {
      outputs[int.parse(m[1]!) - 1] = m[2] == 'ON';
    }
    final armMatch = RegExp(r'STATUS:?(DISARM|PARTSET|PART-SET|SILENT|ARM)').firstMatch(c);
    final arm = switch (armMatch?[1]) {
      null => null,
      'DISARM' => ArmState.disarmed,
      'PARTSET' || 'PART-SET' => ArmState.partset,
      'SILENT' => ArmState.silent,
      _ => ArmState.armed,
    };
    final powerMatch = RegExp(r'(?:POWER|AC|MAINS):?(ON|OFF|OK|FAIL|CONNECTED|DISCONNECTED|CUT)').firstMatch(c);
    final power = switch (powerMatch?[1]) {
      null => null,
      'ON' || 'OK' || 'CONNECTED' => true,
      _ => false,
    };
    final batteryMatch = RegExp(r'(?:BATTERY|BATT|BAT):?(OK|GOOD|FULL|LOW|WEAK)').firstMatch(c);
    final battery = switch (batteryMatch?[1]) {
      null => null,
      'LOW' || 'WEAK' => false,
      _ => true,
    };
    final antenna = int.tryParse(RegExp(r'(?:SIGNAL|ANTENNA|ANT|CSQ):?(\d{1,2})').firstMatch(c)?[1] ?? '');

    final reported = [
      for (var i = 0; i < 4; i++)
        if (outputs[i] != null) i + 1,
    ];
    if (arm == null && power == null && battery == null && antenna == null) {
      if (reported.isEmpty) return null;
      if (reported.length == 1) return _outputReply(reported.single, outputs[reported.single - 1]!);
    }
    final parts = <String>[
      if (arm != null) 'سیستم ${arm.label}',
      for (var i = 0; i < 4; i++)
        if (outputs[i] != null) 'خروجی ${TextNormalizer.toPersianDigits(i + 1)} ${outputs[i]! ? 'روشن' : 'خاموش'}',
      if (power != null) power ? 'برق وصل' : 'برق قطع',
      if (battery != null) battery ? 'باتری سالم' : 'باتری ضعیف',
      if (antenna != null) 'آنتن ${SignalLevel.fromValue(antenna).label}',
    ];
    return ParsedResponse(
      title: 'وضعیت دستگاه',
      detail: parts.join(' • '),
      severity: power == false || battery == false ? MessageSeverity.alert : MessageSeverity.success,
      patch: (s) => s.copyWith(
        arm: arm,
        outputs: [for (var i = 0; i < 4; i++) outputs[i] ?? s.outputs[i]],
        powerConnected: power,
        batteryOk: battery,
        antenna: antenna,
      ),
    );
  }

  bool _on(String word) => word == 'فعال';

  ParsedResponse _outputReply(int output, bool on) => ParsedResponse(
    title: 'خروجی ${TextNormalizer.toPersianDigits(output)} ${on ? 'روشن' : 'خاموش'} شد',
    patch: (s) => s.withOutput(output, on),
    output: output,
  );

  String _state(bool on) => on ? 'فعال' : 'غیرفعال';

  ParsedResponse? _memories(String text) {
    final matches = RegExp(r'M\s*(\d{1,2})\s*:\s*([0-9+*#]*)').allMatches(text).toList();
    if (matches.isEmpty) return null;
    final memories = <int, String>{for (final m in matches) int.parse(m[1]!): m[2]!.trim()};
    final filled = memories.values.where((v) => v.isNotEmpty).length;
    return ParsedResponse(
      title: 'حافظه‌های تلفن',
      detail: '${TextNormalizer.toPersianDigits(filled)} شماره ثبت شده',
      patch: (s) => s.copyWith(memories: {...s.memories, ...memories}),
    );
  }

  ParsedResponse? _status(String text, String c) {
    final isStatus = c.contains('وضعیتدستگاه') || (c.contains('خروجیها') && c.contains('برق'));
    if (!isStatus) return null;

    ArmState? arm;
    if (c.contains('سیستمنیمهفعال')) {
      arm = ArmState.partset;
    } else if (c.contains('سیستمغیرفعال')) {
      arm = ArmState.disarmed;
    } else if (c.contains('سیستمبیصدا')) {
      arm = ArmState.silent;
    } else if (c.contains('سیستمفعال')) {
      arm = ArmState.armed;
    }

    final outputs = <bool?>[null, null, null, null];
    for (final m in RegExp(r'([1-4])\s*[:\-.)]?\s*(روشن|خاموش)').allMatches(text)) {
      outputs[int.parse(m[1]!) - 1] = m[2] == 'روشن';
    }

    bool? power;
    if (c.contains('برقوصل')) power = true;
    if (c.contains('برققطع')) power = false;

    bool? battery;
    final batteryMatch = RegExp('(باطری|باتری):?(سالم|ضعیف)').firstMatch(c);
    if (batteryMatch != null) battery = batteryMatch[2] == 'سالم';

    final parts = <String>[
      if (arm != null) 'سیستم ${arm.label}',
      if (power != null) power ? 'برق وصل' : 'برق قطع',
      if (battery != null) battery ? 'باتری سالم' : 'باتری ضعیف',
    ];
    return ParsedResponse(
      title: 'وضعیت دستگاه',
      detail: parts.join(' • '),
      severity: power == false || battery == false ? MessageSeverity.alert : MessageSeverity.success,
      patch: (s) => s.copyWith(
        arm: arm,
        outputs: [for (var i = 0; i < 4; i++) outputs[i] ?? s.outputs[i]],
        powerConnected: power,
        batteryOk: battery,
      ),
    );
  }

  ParsedResponse? _rules(String c) {
    RegExpMatch? m;

    if (c.toLowerCase().contains('newpassword')) {
      return const ParsedResponse(title: 'رمز قسمت تغییر کرد');
    }

    if ((m = RegExp(r'دسترسی(رمز|ریموت|حافظه)شماره(\d+)بهزونهای([\dو,،]+)').firstMatch(c)) != null) {
      final zones = m![3]!.replaceAll(RegExp('[^1-4]'), '');
      final subject = switch (m[1]) {
        'رمز' => 'رمز کنترلی',
        'ریموت' => 'ریموت',
        _ => 'حافظه',
      };
      return ParsedResponse(
        title: 'پارتیشن $subject ${TextNormalizer.toPersianDigits(int.parse(m[2]!))} تایید شد',
        detail: 'زون‌های ${TextNormalizer.toPersianDigits(zones.split('').join('، '))}',
      );
    }

    if ((m = RegExp(r'خروجی(\d+)=زون').firstMatch(c)) != null) {
      return ParsedResponse(title: 'برنامه‌ریزی خروجی ${TextNormalizer.toPersianDigits(int.parse(m![1]!))} ثبت شد');
    }

    if (c.contains('بلندگو')) {
      final mode = c.contains('بلندگووسیرنغیرفعال')
          ? 2
          : c.contains('بلندگوغیرفعال')
          ? 1
          : 0;
      return ParsedResponse(
        title: 'حالت صدا تغییر کرد',
        detail: SoundModeLabels.of(mode),
        config: {ConfigKeys.soundMode: mode},
      );
    }

    // Manual says «خروجی ۱ فعال شد»; real devices answer «خروجی ۱ روشن».
    if ((m = RegExp('خروجی([1-4]):?(روشن|خاموش|غیرفعال|فعال)').firstMatch(c)) != null) {
      final output = int.parse(m![1]!);
      final on = m[2] == 'روشن' || m[2] == 'فعال';
      return _outputReply(output, on);
    }

    if ((m = RegExp('(دستگاه|دزدگیر|سیستم)(بیصدافعال|نیمهفعال|غیرفعال|فعال)شد').firstMatch(c)) != null) {
      final arm = switch (m![2]) {
        'بیصدافعال' => ArmState.silent,
        'نیمهفعال' => ArmState.partset,
        'غیرفعال' => ArmState.disarmed,
        _ => ArmState.armed,
      };
      return ParsedResponse(
        title: 'دزدگیر ${arm.label} شد',
        patch: (s) => s.copyWith(arm: arm, updatedAt: s.updatedAt),
      );
    }

    if ((m = RegExp(
          'قسمت(\\d)$_onOff'
          'شد',
        ).firstMatch(c)) !=
        null) {
      return ParsedResponse(title: 'قسمت ${TextNormalizer.toPersianDigits(m![1]!)} ${_state(_on(m[2]!))} شد');
    }

    if (c.contains('دربباز')) return const ParsedResponse(title: 'درب باز شد');

    if (c.contains('توقفشمارهگیری')) return const ParsedResponse(title: 'شماره‌گیری متوقف و دستگاه مجدد آرم شد');

    if ((m = RegExp('گزارشریموت$_onOff').firstMatch(c)) != null) {
      final on = _on(m![1]!);
      return ParsedResponse(title: 'گزارش ریموت ${_state(on)} شد', config: {ConfigKeys.remoteReport: on});
    }

    if ((m = RegExp('گزارشبرق$_onOff').firstMatch(c)) != null) {
      final on = _on(m![1]!);
      return ParsedResponse(title: 'گزارش برق ${_state(on)} شد', config: {ConfigKeys.powerReport: on});
    }

    if ((m = RegExp(r'زمانآژیر:?(\d+)').firstMatch(c)) != null) {
      final seconds = int.parse(m![1]!);
      return ParsedResponse(
        title: 'زمان آژیر ${TextNormalizer.toPersianDigits(seconds)} ثانیه تنظیم شد',
        config: {ConfigKeys.sirenTime: seconds},
      );
    }

    if ((m = RegExp('سطحامنیتبالا$_onOff').firstMatch(c)) != null) {
      final high = _on(m![1]!);
      return ParsedResponse(
        title: high ? 'سطح امنیت بالا فعال شد' : 'سطح امنیت متوسط فعال شد',
        config: {ConfigKeys.securityHigh: high},
      );
    }

    if ((m = RegExp(r'ریموتشماره(\d+)حذف').firstMatch(c)) != null) {
      return ParsedResponse(title: 'ریموت ${TextNormalizer.toPersianDigits(int.parse(m![1]!))} حذف شد');
    }

    if ((m = RegExp(r'آنتندهی:?(\d+)').firstMatch(c)) != null) {
      final value = int.parse(m![1]!);
      final level = SignalLevel.fromValue(value);
      return ParsedResponse(
        title: 'قدرت آنتن‌دهی ${TextNormalizer.toPersianDigits(value)}',
        detail: 'وضعیت آنتن: ${level.label}',
        severity: level == SignalLevel.weak ? MessageSeverity.alert : MessageSeverity.success,
        patch: (s) => s.copyWith(antenna: value),
      );
    }

    if ((m = RegExp('اعلامقطعاسپیکر$_onOff').firstMatch(c)) != null) {
      final on = _on(m![1]!);
      return ParsedResponse(title: 'اخطار قطع اسپیکر ${_state(on)} شد', config: {ConfigKeys.speakerReport: on});
    }

    if ((m = RegExp('اعلامقطعفیوز$_onOff').firstMatch(c)) != null) {
      final on = _on(m![1]!);
      return ParsedResponse(title: 'اخطار قطع فیوز ${_state(on)} شد', config: {ConfigKeys.fuseReport: on});
    }

    if ((m = RegExp('پارتیشنبندی$_onOff').firstMatch(c)) != null) {
      final on = _on(m![1]!);
      return ParsedResponse(title: 'پارتیشن‌بندی ${_state(on)} شد', config: {ConfigKeys.partitionMode: on});
    }

    if ((m = RegExp('گزارشباتریسنسور$_onOff').firstMatch(c)) != null) {
      final on = _on(m![1]!);
      return ParsedResponse(title: 'گزارش باتری سنسور ${_state(on)} شد', config: {ConfigKeys.sensorBattery: on});
    }

    if ((m = RegExp('شمارهگیری(تن|پالس)').firstMatch(c)) != null) {
      final pulse = m![1] == 'پالس';
      return ParsedResponse(
        title: 'شماره‌گیری ${pulse ? 'پالس' : 'تن'} تایید شد',
        config: {ConfigKeys.dialPulse: pulse},
      );
    }

    if ((m = RegExp(r'تعدادزنگ(\d)').firstMatch(c)) != null) {
      final rings = int.parse(m![1]!);
      return ParsedResponse(
        title: 'تعداد زنگ ${TextNormalizer.toPersianDigits(rings)} تایید شد',
        config: {ConfigKeys.ringCount: rings},
      );
    }

    if ((m = RegExp('کنترلباتماس$_onOff').firstMatch(c)) != null) {
      final on = _on(m![1]!);
      return ParsedResponse(title: 'کنترل با خط تلفن ${_state(on)} شد', config: {ConfigKeys.landlineControl: on});
    }

    return null;
  }

  ParsedResponse? _alerts(String c) {
    if (c.contains('قطعبرق')) {
      return ParsedResponse(
        title: 'هشدار قطع برق',
        severity: MessageSeverity.alert,
        patch: (s) => s.copyWith(powerConnected: false),
      );
    }
    if (c.contains('وصلبرق') || c.contains('وصلشدنبرق')) {
      return ParsedResponse(title: 'برق دستگاه وصل شد', patch: (s) => s.copyWith(powerConnected: true));
    }
    if (c.contains('اسپیکر')) {
      return const ParsedResponse(title: 'هشدار قطع یا سوختن اسپیکر', severity: MessageSeverity.alert);
    }
    if (c.contains('فیوز')) {
      return const ParsedResponse(title: 'هشدار سوختن فیوز AUX', severity: MessageSeverity.alert);
    }
    if ((c.contains('باتری') || c.contains('باطری')) && c.contains('سنسور')) {
      final zone = RegExp(r'زون(\d)').firstMatch(c)?[1];
      return ParsedResponse(
        title: 'هشدار ضعف باتری سنسور بی‌سیم',
        detail: zone == null ? null : 'زون ${TextNormalizer.toPersianDigits(zone)}',
        severity: MessageSeverity.alert,
      );
    }
    if (c.contains('سرویس')) {
      return const ParsedResponse(title: 'یادآوری سرویس دوره‌ای', severity: MessageSeverity.alert);
    }
    final zone = RegExp(r'زون(\d)').firstMatch(c)?[1];
    if (zone != null || c.contains('آلارم') || c.contains('اضطراری') || c.contains('سرقت') || c.contains('خطر')) {
      return ParsedResponse(
        title: c.contains('اضطراری') ? 'آژیر اضطراری فعال شد' : 'هشدار تحریک دزدگیر',
        detail: zone == null ? null : 'زون ${TextNormalizer.toPersianDigits(zone)}',
        severity: MessageSeverity.alert,
      );
    }
    if (RegExp('(ریال|تومان|اعتبار|شارژ|موجودی)').hasMatch(c) || c.toLowerCase().contains('balance')) {
      return const ParsedResponse(title: 'اطلاعات شارژ سیم‌کارت', severity: MessageSeverity.info);
    }
    return null;
  }
}

abstract final class SoundModeLabels {
  static String of(int mode) => switch (mode) {
    1 => 'بلندگو غیرفعال، پیزو فعال',
    2 => 'بلندگو و پیزو غیرفعال',
    _ => 'بلندگو و پیزو فعال',
  };
}
