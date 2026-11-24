import 'package:equatable/equatable.dart';

enum ArmState {
  armed('فعال'),
  disarmed('غیرفعال'),
  partset('نیمه فعال'),
  silent('فعال بی‌صدا'),
  unknown('نامشخص');

  const ArmState(this.label);
  final String label;
}

enum SignalLevel {
  good('خوب'),
  medium('متوسط'),
  weak('ضعیف');

  const SignalLevel(this.label);
  final String label;

  /// Thresholds from the manual: 20-30 good, 15-19 medium, below 15 weak.
  static SignalLevel fromValue(int value) {
    if (value >= 20) return good;
    if (value >= 15) return medium;
    return weak;
  }
}

typedef StatusPatch = DeviceStatus Function(DeviceStatus status);

/// Last known device state, assembled from parsed device replies.
/// Each field remembers when the SMS that reported it was received ([stamps]), so a reply that is
/// processed late (inbox sync, pasted, queued while the app was closed) only updates the fields it is
/// actually newer for, and the newest SMS always wins regardless of processing order.
class DeviceStatus extends Equatable {
  const DeviceStatus({
    this.arm = ArmState.unknown,
    this.outputs = const [null, null, null, null],
    this.powerConnected,
    this.batteryOk,
    this.antenna,
    this.memories = const {},
    this.updatedAt,
    this.stamps = const {},
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) => _withLegacyStamps(
    DeviceStatus(
      arm: ArmState.values.asNameMap()[json['arm']] ?? ArmState.unknown,
      outputs: [
        for (final o in (json['outputs'] as List? ?? const [null, null, null, null])) o as bool?,
      ],
      powerConnected: json['power'] as bool?,
      batteryOk: json['battery'] as bool?,
      antenna: json['antenna'] as int?,
      memories: {for (final e in (json['memories'] as Map? ?? const {}).entries) int.parse('${e.key}'): '${e.value}'},
      updatedAt: json['updatedAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      stamps: {
        for (final e in (json['stamps'] as Map? ?? const {}).entries)
          '${e.key}': DateTime.fromMillisecondsSinceEpoch((e.value as num).toInt()),
      },
    ),
  );

  /// Status saved before per-field stamps existed: its values date from [updatedAt].
  static DeviceStatus _withLegacyStamps(DeviceStatus s) {
    if (s.stamps.isNotEmpty || s.updatedAt == null) return s;
    final at = s.updatedAt!;
    return s.copyWith(stamps: {for (final key in s._reportedKeys) key: at});
  }

  static const _arm = 'arm';
  static const _power = 'power';
  static const _battery = 'battery';
  static const _antenna = 'antenna';
  static String _output(int index) => 'out${index + 1}';
  static String _memory(int memory) => 'mem$memory';

  /// Stamp keys of the fields that hold a reading.
  List<String> get _reportedKeys => [
    if (arm != ArmState.unknown) _arm,
    for (var i = 0; i < outputs.length; i++)
      if (outputs[i] != null) _output(i),
    if (powerConnected != null) _power,
    if (batteryOk != null) _battery,
    if (antenna != null) _antenna,
    for (final m in memories.keys) _memory(m),
  ];

  static const empty = DeviceStatus();

  final ArmState arm;
  final List<bool?> outputs;
  final bool? powerConnected;
  final bool? batteryOk;
  final int? antenna;
  final Map<int, String> memories;

  /// Receive time of the newest SMS behind [arm], [outputs] etc.; null when nothing was reported yet.
  final DateTime? updatedAt;

  /// Receive time of the SMS that set each field.
  final Map<String, DateTime> stamps;

  SignalLevel? get signal => antenna == null ? null : SignalLevel.fromValue(antenna!);

  DeviceStatus copyWith({
    ArmState? arm,
    List<bool?>? outputs,
    bool? powerConnected,
    bool? batteryOk,
    int? antenna,
    Map<int, String>? memories,
    DateTime? updatedAt,
    Map<String, DateTime>? stamps,
  }) => DeviceStatus(
    arm: arm ?? this.arm,
    outputs: outputs ?? this.outputs,
    powerConnected: powerConnected ?? this.powerConnected,
    batteryOk: batteryOk ?? this.batteryOk,
    antenna: antenna ?? this.antenna,
    memories: memories ?? this.memories,
    updatedAt: updatedAt ?? this.updatedAt,
    stamps: stamps ?? this.stamps,
  );

  /// Applies an SMS received at [at]: every field the SMS reports is taken only when no newer SMS
  /// already set it. Returns this status unchanged when the SMS is older for every field.
  DeviceStatus applyAt(StatusPatch patch, DateTime at) {
    final reported = patch(DeviceStatus.empty);
    final next = patch(this);
    final stamps = {...this.stamps};
    var changed = false;

    bool take(String key) {
      final stamp = stamps[key];
      if (stamp != null && at.isBefore(stamp)) return false;
      stamps[key] = at;
      changed = true;
      return true;
    }

    final arm = reported.arm != ArmState.unknown && take(_arm) ? next.arm : this.arm;
    final outputs = [
      for (var i = 0; i < this.outputs.length; i++)
        i < reported.outputs.length && reported.outputs[i] != null && take(_output(i))
            ? next.outputs[i]
            : this.outputs[i],
    ];
    final power = reported.powerConnected != null && take(_power) ? next.powerConnected : powerConnected;
    final battery = reported.batteryOk != null && take(_battery) ? next.batteryOk : batteryOk;
    final antenna = reported.antenna != null && take(_antenna) ? next.antenna : this.antenna;
    final memories = {...this.memories};
    for (final m in reported.memories.keys) {
      if (take(_memory(m))) memories[m] = next.memories[m] ?? '';
    }
    if (!changed) return this;

    return DeviceStatus(
      arm: arm,
      outputs: outputs,
      powerConnected: power,
      batteryOk: battery,
      antenna: antenna,
      memories: memories,
      updatedAt: updatedAt == null || at.isAfter(updatedAt!) ? at : updatedAt,
      stamps: stamps,
    );
  }

  DeviceStatus withOutput(int output, bool on) {
    final next = [...outputs];
    next[output - 1] = on;
    return copyWith(outputs: next);
  }

  Map<String, dynamic> toJson() => {
    'arm': arm.name,
    'outputs': outputs,
    'power': powerConnected,
    'battery': batteryOk,
    'antenna': antenna,
    'memories': {for (final e in memories.entries) '${e.key}': e.value},
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
    'stamps': {for (final e in stamps.entries) e.key: e.value.millisecondsSinceEpoch},
  };

  @override
  List<Object?> get props => [arm, outputs, powerConnected, batteryOk, antenna, memories, updatedAt, stamps];
}
