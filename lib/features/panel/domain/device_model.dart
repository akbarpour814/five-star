/// Every SMS capability a FiveStar panel can have. Which model has which comes from the
/// code/answer table (کدها و جواب‌ها) plus, for the GSA-212, its own manual.
enum DeviceFeature {
  /// `10000`…`40000` permanent and `1L0000`…`4L0000` momentary output control.
  outputs,
  partSet, // 7
  silentArm, // 8
  customTexts, // A
  memoryInquiry, // C
  openDoor, // D
  stopDialing, // F
  ussd, // G
  remoteReport, // H
  powerReport, // I
  sirenTime, // J
  securityLevel, // K
  deleteRemote, // L
  soundMode, // M
  antenna, // N
  speakerReport, // O
  outputProgram, // R
  passwordPartition, // S
  fuseReport, // T
  remotePartition, // U
  partControl, // V
  partitionMode, // W
  partPassword, // X
  memoryPartition, // Y
  zoneSettings, // Z
  notificationPartition, // +
  sensorBattery, // @
  dialMode, // !
  ringCount, // ?
  landlineControl, // %
  // GSA-212 manual only (not in the shared code table).
  changePassword, // 0
  simBalance, // *
  simCharge, // #
  autoBalance, // P
  serviceReminder, // Q
}

/// Event a custom message text (A command) replaces.
enum TextEvent {
  arm,
  disarm,
  partset,
  silentArm,
  outputOn,
  outputOff,
  powerCut,
  powerRestored,
  alarm,
  zoneAlarm,
  phoneLineCut,
  lowBattery,
  keypadAlarm,
}

/// One programmable message text: [code] is the two letters after `A` in the table (e.g. `AA`).
class TextSlot {
  const TextSlot(this.code, this.label, this.event, [this.index]);

  final String code;
  final String label;
  final TextEvent event;

  /// Output or zone number for [TextEvent.outputOn], [TextEvent.outputOff] and [TextEvent.zoneAlarm].
  final int? index;
}

const _outputTexts = [
  TextSlot('AC', 'متن فعال شدن خروجی ۱', TextEvent.outputOn, 1),
  TextSlot('AD', 'متن غیرفعال شدن خروجی ۱', TextEvent.outputOff, 1),
  TextSlot('AE', 'متن فعال شدن خروجی ۲', TextEvent.outputOn, 2),
  TextSlot('AF', 'متن غیرفعال شدن خروجی ۲', TextEvent.outputOff, 2),
  TextSlot('AG', 'متن فعال شدن خروجی ۳', TextEvent.outputOn, 3),
  TextSlot('AH', 'متن غیرفعال شدن خروجی ۳', TextEvent.outputOff, 3),
  TextSlot('AI', 'متن فعال شدن خروجی ۴', TextEvent.outputOn, 4),
  TextSlot('AJ', 'متن غیرفعال شدن خروجی ۴', TextEvent.outputOff, 4),
];

/// GSA-206 table (also used for GSA-207P, which has the same feature column and no table of its own).
const _texts206 = [
  TextSlot('AA', 'متن فعال شدن دستگاه', TextEvent.arm),
  TextSlot('AB', 'متن غیرفعال شدن دستگاه', TextEvent.disarm),
  ..._outputTexts,
  TextSlot('AK', 'متن قطع برق', TextEvent.powerCut),
  TextSlot('AL', 'متن وصل برق', TextEvent.powerRestored),
  TextSlot('AM', 'متن آلارم', TextEvent.alarm),
  TextSlot('AN', 'متن قطع تلفن', TextEvent.phoneLineCut),
];

const _texts206Plus = [
  TextSlot('AA', 'متن فعال شدن دستگاه', TextEvent.arm),
  TextSlot('AB', 'متن غیرفعال شدن دستگاه', TextEvent.disarm),
  ..._outputTexts,
  TextSlot('AK', 'متن آلارم زون ۱', TextEvent.zoneAlarm, 1),
  TextSlot('AL', 'متن آلارم زون ۲', TextEvent.zoneAlarm, 2),
  TextSlot('AM', 'متن آلارم زون ۳', TextEvent.zoneAlarm, 3),
  TextSlot('AN', 'متن آلارم زون ۴', TextEvent.zoneAlarm, 4),
];

const _texts208 = [
  TextSlot('AA', 'متن آلارم زون ۱', TextEvent.zoneAlarm, 1),
  TextSlot('AB', 'متن آلارم زون ۲', TextEvent.zoneAlarm, 2),
  TextSlot('AC', 'متن آلارم زون ۳', TextEvent.zoneAlarm, 3),
  TextSlot('AD', 'متن آلارم زون ۴', TextEvent.zoneAlarm, 4),
  TextSlot('AE', 'متن آلارم زون ۵', TextEvent.zoneAlarm, 5),
  TextSlot('AF', 'متن آلارم زون ۶', TextEvent.zoneAlarm, 6),
  TextSlot('AG', 'متن آلارم زون ۷', TextEvent.zoneAlarm, 7),
  TextSlot('AH', 'متن آلارم زون ۸', TextEvent.zoneAlarm, 8),
  TextSlot('AI', 'متن فعال شدن پنل', TextEvent.arm),
  TextSlot('AJ', 'متن غیرفعال شدن پنل', TextEvent.disarm),
  TextSlot('AK', 'متن نیمه فعال شدن پنل', TextEvent.partset),
  TextSlot('AL', 'متن بی‌صدا فعال شدن پنل', TextEvent.silentArm),
  TextSlot('AM', 'متن فعال شدن خروجی ۱', TextEvent.outputOn, 1),
  TextSlot('AN', 'متن غیرفعال شدن خروجی ۱', TextEvent.outputOff, 1),
  TextSlot('AO', 'متن فعال شدن خروجی ۲', TextEvent.outputOn, 2),
  TextSlot('AP', 'متن غیرفعال شدن خروجی ۲', TextEvent.outputOff, 2),
  TextSlot('AQ', 'متن فعال شدن خروجی ۳', TextEvent.outputOn, 3),
  TextSlot('AR', 'متن غیرفعال شدن خروجی ۳', TextEvent.outputOff, 3),
  TextSlot('AS', 'متن فعال شدن خروجی ۴', TextEvent.outputOn, 4),
  TextSlot('AT', 'متن غیرفعال شدن خروجی ۴', TextEvent.outputOff, 4),
  TextSlot('AU', 'متن قطع برق', TextEvent.powerCut),
  TextSlot('AV', 'متن کم بودن باتری پنل', TextEvent.lowBattery),
  TextSlot('AW', 'متن وصل شدن برق پنل', TextEvent.powerRestored),
  TextSlot('AX', 'متن آلارم زون امنیتی کیپد', TextEvent.keypadAlarm),
];

const _base = {DeviceFeature.memoryInquiry};
const _outputsUssd = {DeviceFeature.outputs, DeviceFeature.stopDialing, DeviceFeature.ussd};

/// FiveStar panel models from the code/answer table. [code] is what is stored on the device record.
enum DeviceModel {
  gsa206(
    code: 'GSA-206',
    memoryCount: 30,
    features: {..._base, ..._outputsUssd, DeviceFeature.customTexts, DeviceFeature.powerReport},
    texts: _texts206,
  ),
  gsa207p(
    code: 'GSA-207P',
    memoryCount: 30,
    features: {..._base, ..._outputsUssd, DeviceFeature.customTexts, DeviceFeature.powerReport},
    texts: _texts206,
  ),
  gsa206Plus(
    code: 'GSA-206+',
    memoryCount: 30,
    features: {
      ..._base,
      ..._outputsUssd,
      DeviceFeature.partSet,
      DeviceFeature.silentArm,
      DeviceFeature.customTexts,
      DeviceFeature.openDoor,
      DeviceFeature.remoteReport,
      DeviceFeature.powerReport,
      DeviceFeature.soundMode,
    },
    texts: _texts206Plus,
  ),
  gsa209Plus(
    code: 'GSA-209+',
    memoryCount: 20,
    features: {
      ..._base,
      ..._outputsUssd,
      DeviceFeature.partSet,
      DeviceFeature.silentArm,
      DeviceFeature.openDoor,
      DeviceFeature.remoteReport,
      DeviceFeature.powerReport,
      DeviceFeature.soundMode,
    },
  ),
  gsa211Plus(
    code: 'GSA-211+',
    memoryCount: 20,
    features: {
      ..._base,
      ..._outputsUssd,
      DeviceFeature.partSet,
      DeviceFeature.silentArm,
      DeviceFeature.openDoor,
      DeviceFeature.remoteReport,
      DeviceFeature.powerReport,
      DeviceFeature.sirenTime,
      DeviceFeature.securityLevel,
      DeviceFeature.deleteRemote,
      DeviceFeature.soundMode,
      DeviceFeature.antenna,
      DeviceFeature.speakerReport,
      DeviceFeature.fuseReport,
      DeviceFeature.zoneSettings,
    },
  ),
  gsa212(
    code: 'GSA-212',
    memoryCount: 30,
    features: {
      ..._base,
      ..._outputsUssd,
      DeviceFeature.partSet,
      DeviceFeature.silentArm,
      DeviceFeature.openDoor,
      DeviceFeature.remoteReport,
      DeviceFeature.powerReport,
      DeviceFeature.sirenTime,
      DeviceFeature.securityLevel,
      DeviceFeature.deleteRemote,
      DeviceFeature.soundMode,
      DeviceFeature.antenna,
      DeviceFeature.speakerReport,
      DeviceFeature.outputProgram,
      DeviceFeature.passwordPartition,
      DeviceFeature.fuseReport,
      DeviceFeature.remotePartition,
      DeviceFeature.partControl,
      DeviceFeature.partitionMode,
      DeviceFeature.partPassword,
      DeviceFeature.memoryPartition,
      DeviceFeature.zoneSettings,
      DeviceFeature.notificationPartition,
      DeviceFeature.sensorBattery,
      DeviceFeature.dialMode,
      DeviceFeature.ringCount,
      DeviceFeature.landlineControl,
      DeviceFeature.changePassword,
      DeviceFeature.simBalance,
      DeviceFeature.simCharge,
      DeviceFeature.autoBalance,
      DeviceFeature.serviceReminder,
    },
  ),
  gsa208(
    code: 'GSA-208',
    memoryCount: 30,
    textZoneCount: 8,
    features: {
      ..._base,
      ..._outputsUssd,
      DeviceFeature.partSet,
      DeviceFeature.silentArm,
      DeviceFeature.customTexts,
      DeviceFeature.openDoor,
      DeviceFeature.deleteRemote,
      DeviceFeature.speakerReport,
    },
    texts: _texts208,
  ),
  gsa220(code: 'GSA-220', memoryCount: 10, features: _base);

  const DeviceModel({
    required this.code,
    required this.memoryCount,
    required this.features,
    this.texts = const [],
    this.textZoneCount = 4,
  });

  final String code;

  /// Phone memories answered by `C` (`M1`…`M<n>`) and accepted by `E`.
  final int memoryCount;
  final Set<DeviceFeature> features;

  /// Programmable message texts (A command), in table order.
  final List<TextSlot> texts;

  /// Zones the panel reports in alarms (8 on the GSA-208, 4 elsewhere).
  final int textZoneCount;

  static const outputCount = 4;
  static const zoneCount = 4;
  static const remoteCount = 30;
  static const partCount = 4;

  /// Records saved before model selection existed belong to the GSA-212.
  static const fallback = gsa212;
  static const fallbackCode = 'GSA-212';

  /// Order shown in the model picker.
  static const pickerOrder = [gsa206, gsa207p, gsa206Plus, gsa208, gsa209Plus, gsa211Plus, gsa212, gsa220];

  static DeviceModel fromCode(String? code) => values.firstWhere((m) => m.code == code, orElse: () => fallback);

  bool has(DeviceFeature feature) => features.contains(feature);

  bool hasAny(Iterable<DeviceFeature> list) => list.any(features.contains);

  int get outputs => has(DeviceFeature.outputs) ? outputCount : 0;

  /// Memory groups of the GSA-212 manual; the other models only document a single list.
  bool get hasMemoryGroups => this == gsa212;

  TextSlot? textSlot(String code) {
    for (final slot in texts) {
      if (slot.code == code) return slot;
    }
    return null;
  }

  /// `M0`/`M1`/`M2` meaning. The GSA-212 manual names the piezo; the shared table names the siren.
  String soundModeLabel(int mode) => switch ((this == gsa212, mode)) {
    (true, 1) => 'بلندگو غیرفعال، پیزو فعال',
    (true, 2) => 'بلندگو و پیزو غیرفعال',
    (true, _) => 'بلندگو و پیزو فعال',
    (false, 1) => 'بلندگو غیرفعال',
    (false, 2) => 'بلندگو و سیرن غیرفعال',
    (false, _) => 'بلندگو و سیرن فعال',
  };

  /// One-line summary for the model picker.
  String get summary => switch (this) {
    gsa206 || gsa207p => '۴ خروجی • ۳۰ حافظه • تغییر متن پیام‌ها',
    gsa206Plus => '۴ خروجی • نیمه فعال • درب‌بازکن • تغییر متن',
    gsa209Plus => '۴ خروجی • نیمه فعال • درب‌بازکن • ۲۰ حافظه',
    gsa211Plus => 'زون، آژیر، امنیت، آنتن و ریموت • ۲۰ حافظه',
    gsa212 => 'کامل‌ترین: پارتیشن‌بندی، خط تلفن و شارژ',
    gsa208 => '۸ زون • تغییر متن پیام‌ها • حذف ریموت',
    gsa220 => 'فعال/غیرفعال • ۱۰ حافظه',
  };
}
