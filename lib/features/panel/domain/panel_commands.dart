import 'device_command.dart';
import 'device_model.dart';

abstract final class ConfigKeys {
  static const remoteReport = 'remoteReport';
  static const powerReport = 'powerReport';
  static const sirenTime = 'sirenTime';
  static const securityHigh = 'securityHigh';
  static const soundMode = 'soundMode';
  static const speakerReport = 'speakerReport';
  static const autoBalance = 'autoBalance';
  static const serviceDays = 'serviceDays';
  static const fuseReport = 'fuseReport';
  static const sensorBattery = 'sensorBattery';
  static const dialPulse = 'dialPulse';
  static const ringCount = 'ringCount';
  static const landlineControl = 'landlineControl';
  static const partitionMode = 'partitionMode';
  static String zone(int zone) => 'zone$zone';
  static String outputMode(int output) => 'outputMode$output';
  static String notify(int zone) => 'notify$zone';

  /// Custom message text programmed with the A command, keyed by its slot code (e.g. `AA`).
  static String text(String slot) => 'text$slot';
}

typedef _Part = (String text, bool secret);

/// SMS command catalogue shared by every FiveStar panel (code/answer table, plus the GSA-212 manual).
/// Each builder checks that [model] supports it. [password] is the 4-digit control password (factory default 0000).
class PanelCommands {
  const PanelCommands(this.model, this.password);

  final DeviceModel model;
  final String password;

  static const remoteCount = DeviceModel.remoteCount;
  static const zoneCount = DeviceModel.zoneCount;
  static const outputCount = DeviceModel.outputCount;

  int get memoryCount => model.memoryCount;

  void _need(DeviceFeature feature) {
    if (!model.has(feature)) throw UnsupportedError('${model.code} does not support ${feature.name}');
  }

  static final _fourDigits = RegExp(r'^\d{4}$');

  static bool isValidPassword(String value) => _fourDigits.hasMatch(value);

  DeviceCommand _build(String title, List<_Part> parts, {Map<String, Object?> config = const {}}) {
    final body = parts.map((p) => p.$1).join();
    final masked = parts.map((p) => p.$2 ? '•' * p.$1.length : p.$1).join();
    return DeviceCommand(title: title, body: body, maskedBody: masked, configPatch: config);
  }

  DeviceCommand _simple(String title, String prefix, {String suffix = '', Map<String, Object?> config = const {}}) =>
      _build(title, [(prefix, false), (password, true), if (suffix.isNotEmpty) (suffix, false)], config: config);

  static String _pad(int value, int width) => value.toString().padLeft(width, '0');

  static void _range(int value, int min, int max, String name) {
    if (value < min || value > max) throw ArgumentError.value(value, name, 'must be $min..$max');
  }

  static String _flag(bool value) => value ? '1' : '0';

  // ---- Panel control ----
  DeviceCommand arm() => _simple('فعال کردن دزدگیر', '5');
  DeviceCommand disarm() => _simple('غیرفعال کردن دزدگیر', '6');
  DeviceCommand partSet() {
    _need(DeviceFeature.partSet);
    return _simple('نیمه فعال کردن دزدگیر', '7');
  }

  DeviceCommand silentArm() {
    _need(DeviceFeature.silentArm);
    return _simple('فعال کردن بی‌صدا', '8');
  }

  DeviceCommand outputToggle(int output) {
    _need(DeviceFeature.outputs);
    _range(output, 1, outputCount, 'output');
    return _simple('کنترل دائم خروجی $output', '$output', config: {ConfigKeys.outputMode(output): 'toggle'});
  }

  DeviceCommand outputMomentary(int output) {
    _need(DeviceFeature.outputs);
    _range(output, 1, outputCount, 'output');
    return _simple('کنترل لحظه‌ای خروجی $output', '${output}L', config: {ConfigKeys.outputMode(output): 'momentary'});
  }

  DeviceCommand openDoor() {
    _need(DeviceFeature.openDoor);
    return _simple('فعال کردن درب‌بازکن', 'D');
  }

  DeviceCommand stopDialing() {
    _need(DeviceFeature.stopDialing);
    return _simple('توقف شماره‌گیری', 'F');
  }

  // ---- Inquiries ----
  DeviceCommand status() => _simple('استعلام وضعیت دستگاه', 'B');
  DeviceCommand memories() {
    _need(DeviceFeature.memoryInquiry);
    return _simple('استعلام حافظه‌های تلفن', 'C');
  }

  DeviceCommand antenna() {
    _need(DeviceFeature.antenna);
    return _simple('استعلام قدرت آنتن‌دهی', 'N');
  }

  DeviceCommand simBalance() {
    _need(DeviceFeature.simBalance);
    return _simple('استعلام شارژ سیم‌کارت', '*');
  }

  // ---- SIM ----
  DeviceCommand simCharge(String chargeCode) {
    _need(DeviceFeature.simCharge);
    final code = chargeCode.trim();
    if (code.isEmpty) throw ArgumentError.value(chargeCode, 'chargeCode');
    return _simple('شارژ سیم‌کارت', '#', suffix: code);
  }

  DeviceCommand ussd(String code) {
    _need(DeviceFeature.ussd);
    final value = code.trim();
    if (value.isEmpty) throw ArgumentError.value(code, 'code');
    return _simple('اجرای کد USSD', 'G', suffix: value);
  }

  DeviceCommand autoBalance(int smsCount) {
    _need(DeviceFeature.autoBalance);
    _range(smsCount, 1, 255, 'smsCount');
    return _simple('استعلام شارژ خودکار', 'P', suffix: _pad(smsCount, 3), config: {ConfigKeys.autoBalance: smsCount});
  }

  // ---- Security ----
  DeviceCommand changePassword(String newPassword) {
    _need(DeviceFeature.changePassword);
    if (!isValidPassword(newPassword)) throw ArgumentError.value(newPassword, 'newPassword');
    return _build('تغییر رمز دستگاه', [('0', false), (password, true), (newPassword, true)]);
  }

  DeviceCommand securityLevel({required bool high}) {
    _need(DeviceFeature.securityLevel);
    return _simple(
      high ? 'سطح امنیت بالا' : 'سطح امنیت متوسط',
      'K${_flag(high)}',
      config: {ConfigKeys.securityHigh: high},
    );
  }

  // ---- Message texts (A) ----

  /// Longest text kept to one SMS: Persian is sent as UCS-2 (70 chars) and the prefix takes 6.
  static const maxTextLength = 60;

  DeviceCommand customText(TextSlot slot, String text) {
    _need(DeviceFeature.customTexts);
    final value = text.trim();
    if (value.isEmpty || value.length > maxTextLength) throw ArgumentError.value(text, 'text');
    if (model.textSlot(slot.code) == null) throw ArgumentError.value(slot.code, 'slot');
    return _build(
      slot.label,
      [(slot.code, false), (password, true), (value, false)],
      config: {ConfigKeys.text(slot.code): value},
    );
  }

  // ---- Phone memories ----
  DeviceCommand saveNumber({required int memory, required String phone}) {
    _range(memory, 1, memoryCount, 'memory');
    return _build('ثبت شماره در حافظه $memory', [('E', false), (password, true), ('${_pad(memory, 2)}$phone', false)]);
  }

  // ---- Reports / alerts ----
  DeviceCommand remoteReport(bool on) {
    _need(DeviceFeature.remoteReport);
    return _simple(
      on ? 'فعال کردن گزارش ریموت' : 'غیرفعال کردن گزارش ریموت',
      'H${_flag(on)}',
      config: {ConfigKeys.remoteReport: on},
    );
  }

  DeviceCommand powerReport(bool on) {
    _need(DeviceFeature.powerReport);
    return _simple(
      on ? 'فعال کردن گزارش برق' : 'غیرفعال کردن گزارش برق',
      'I${_flag(on)}',
      config: {ConfigKeys.powerReport: on},
    );
  }

  DeviceCommand speakerCutReport(bool on) {
    _need(DeviceFeature.speakerReport);
    return _simple(
      on ? 'اخطار قطع اسپیکر روشن' : 'اخطار قطع اسپیکر خاموش',
      'O${_flag(on)}',
      config: {ConfigKeys.speakerReport: on},
    );
  }

  DeviceCommand fuseReport(bool on) {
    _need(DeviceFeature.fuseReport);
    return _simple(
      on ? 'اخطار قطع فیوز AUX روشن' : 'اخطار قطع فیوز AUX خاموش',
      'T${_flag(on)}',
      config: {ConfigKeys.fuseReport: on},
    );
  }

  DeviceCommand sensorBatteryReport(bool on) {
    _need(DeviceFeature.sensorBattery);
    return _simple(
      on ? 'گزارش باتری سنسور بی‌سیم روشن' : 'گزارش باتری سنسور بی‌سیم خاموش',
      '@${_flag(on)}',
      config: {ConfigKeys.sensorBattery: on},
    );
  }

  DeviceCommand serviceReminder(int days) {
    _need(DeviceFeature.serviceReminder);
    _range(days, 1, 255, 'days');
    return _simple('یادآوری سرویس دوره‌ای', 'Q', suffix: _pad(days, 3), config: {ConfigKeys.serviceDays: days});
  }

  // ---- Siren / sound ----
  DeviceCommand sirenTime(int seconds) {
    _need(DeviceFeature.sirenTime);
    _range(seconds, 0, 255, 'seconds');
    return _simple('تنظیم زمان آژیر', 'J', suffix: _pad(seconds, 3), config: {ConfigKeys.sirenTime: seconds});
  }

  DeviceCommand soundMode(SoundMode mode) {
    _need(DeviceFeature.soundMode);
    return _simple(
      'حالت صدا: ${model.soundModeLabel(mode.code)}',
      'M${mode.code}',
      config: {ConfigKeys.soundMode: mode.code},
    );
  }

  // ---- Remotes ----
  DeviceCommand deleteRemote(int remote) {
    _need(DeviceFeature.deleteRemote);
    _range(remote, 1, remoteCount, 'remote');
    return _simple('حذف ریموت $remote', 'L', suffix: _pad(remote, 3));
  }

  // ---- Zones ----
  DeviceCommand zoneSettings({
    required int zone,
    required bool normallyClosed,
    required bool dingDong,
    required ZoneType type,
    int delaySeconds = 0,
  }) {
    _need(DeviceFeature.zoneSettings);
    _range(zone, 1, zoneCount, 'zone');
    final delay = type == ZoneType.delayed ? delaySeconds : 0;
    _range(delay, 0, 255, 'delaySeconds');
    return _build(
      'تنظیمات زون $zone',
      [
        ('Z$zone', false),
        (password, true),
        ('${_flag(normallyClosed)}${_flag(dingDong)}${type.code}${_pad(delay, 3)}', false),
      ],
      config: {
        ConfigKeys.zone(zone): {'nc': normallyClosed, 'dingDong': dingDong, 'type': type.code, 'delay': delay},
      },
    );
  }

  // ---- Telephone line ----
  DeviceCommand dialMode({required bool pulse}) {
    _need(DeviceFeature.dialMode);
    return _simple(
      pulse ? 'شماره‌گیری پالس' : 'شماره‌گیری تن',
      '!${_flag(pulse)}',
      config: {ConfigKeys.dialPulse: pulse},
    );
  }

  DeviceCommand ringCount(int rings) {
    _need(DeviceFeature.ringCount);
    _range(rings, 1, 9, 'rings');
    return _build(
      'تنظیم تعداد بوق تلفن',
      [('?$rings', false), (password, true)],
      config: {ConfigKeys.ringCount: rings},
    );
  }

  DeviceCommand landlineControl(bool on) {
    _need(DeviceFeature.landlineControl);
    return _simple(
      on ? 'کنترل با خط تلفن روشن' : 'کنترل با خط تلفن خاموش',
      '%${_flag(on)}',
      config: {ConfigKeys.landlineControl: on},
    );
  }

  // ---- Partitions (special features) ----
  DeviceCommand partitionMode(bool on) {
    _need(DeviceFeature.partitionMode);
    return _simple(
      on ? 'فعال کردن پارتیشن‌بندی' : 'غیرفعال کردن پارتیشن‌بندی',
      'W${_flag(on)}',
      config: {ConfigKeys.partitionMode: on},
    );
  }

  DeviceCommand remotePartition({required int remote, required ZoneMask zones}) {
    _need(DeviceFeature.remotePartition);
    _range(remote, 1, remoteCount, 'remote');
    return _build('پارتیشن ریموت $remote', [('U${_pad(remote, 2)}', false), (password, true), (zones.code, false)]);
  }

  DeviceCommand memoryPartition({required int memory, required ZoneMask zones}) {
    _need(DeviceFeature.memoryPartition);
    _range(memory, 1, memoryCount, 'memory');
    return _build('پارتیشن حافظه $memory', [('Y${_pad(memory, 2)}', false), (password, true), (zones.code, false)]);
  }

  DeviceCommand passwordPartition({required int part, required ZoneMask zones}) {
    _need(DeviceFeature.passwordPartition);
    _range(part, 1, 4, 'part');
    return _build('دسترسی رمز کنترلی $part', [('S${_pad(part, 2)}', false), (password, true), (zones.code, false)]);
  }

  DeviceCommand partPasswordChange({required int part, required String oldPassword, required String newPassword}) {
    _need(DeviceFeature.partPassword);
    _range(part, 1, 4, 'part');
    if (!isValidPassword(oldPassword)) throw ArgumentError.value(oldPassword, 'oldPassword');
    if (!isValidPassword(newPassword)) throw ArgumentError.value(newPassword, 'newPassword');
    return _build('تغییر رمز قسمت $part', [('X$part', false), (oldPassword, true), (newPassword, true)]);
  }

  DeviceCommand partControl({required int part, required bool arm, required String partPassword}) {
    _need(DeviceFeature.partControl);
    _range(part, 1, 4, 'part');
    if (!isValidPassword(partPassword)) throw ArgumentError.value(partPassword, 'partPassword');
    return _build(arm ? 'فعال کردن قسمت $part' : 'غیرفعال کردن قسمت $part', [
      ('V$part${arm ? 'A' : 'D'}', false),
      (partPassword, true),
    ]);
  }

  DeviceCommand outputProgram({required int output, required ZoneMask zones, required int seconds}) {
    _need(DeviceFeature.outputProgram);
    _range(output, 1, outputCount, 'output');
    _range(seconds, 0, 255, 'seconds');
    return _build('برنامه‌ریزی خروجی $output', [
      ('R${_pad(output, 2)}', false),
      (password, true),
      ('${zones.code}${_pad(seconds, 3)}', false),
    ]);
  }

  DeviceCommand notificationPartition({required int zone, required bool siren, required bool sms, required bool call}) {
    _need(DeviceFeature.notificationPartition);
    _range(zone, 1, zoneCount, 'zone');
    return _build(
      'اطلاع‌رسانی زون $zone',
      [('+$zone', false), (password, true), ('${_flag(siren)}${_flag(sms)}${_flag(call)}', false)],
      config: {
        ConfigKeys.notify(zone): {'siren': siren, 'sms': sms, 'call': call},
      },
    );
  }
}
