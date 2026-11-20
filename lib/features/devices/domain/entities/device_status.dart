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

/// Last known device state, assembled from parsed device replies.
class DeviceStatus extends Equatable {
  const DeviceStatus({
    this.arm = ArmState.unknown,
    this.outputs = const [null, null, null, null],
    this.powerConnected,
    this.batteryOk,
    this.antenna,
    this.memories = const {},
    this.updatedAt,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) => DeviceStatus(
    arm: ArmState.values.asNameMap()[json['arm']] ?? ArmState.unknown,
    outputs: [
      for (final o in (json['outputs'] as List? ?? const [null, null, null, null])) o as bool?,
    ],
    powerConnected: json['power'] as bool?,
    batteryOk: json['battery'] as bool?,
    antenna: json['antenna'] as int?,
    memories: {for (final e in (json['memories'] as Map? ?? const {}).entries) int.parse('${e.key}'): '${e.value}'},
    updatedAt: json['updatedAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
  );

  static const empty = DeviceStatus();

  final ArmState arm;
  final List<bool?> outputs;
  final bool? powerConnected;
  final bool? batteryOk;
  final int? antenna;
  final Map<int, String> memories;
  final DateTime? updatedAt;

  SignalLevel? get signal => antenna == null ? null : SignalLevel.fromValue(antenna!);

  DeviceStatus copyWith({
    ArmState? arm,
    List<bool?>? outputs,
    bool? powerConnected,
    bool? batteryOk,
    int? antenna,
    Map<int, String>? memories,
    DateTime? updatedAt,
  }) => DeviceStatus(
    arm: arm ?? this.arm,
    outputs: outputs ?? this.outputs,
    powerConnected: powerConnected ?? this.powerConnected,
    batteryOk: batteryOk ?? this.batteryOk,
    antenna: antenna ?? this.antenna,
    memories: memories ?? this.memories,
    updatedAt: updatedAt ?? this.updatedAt,
  );

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
  };

  @override
  List<Object?> get props => [arm, outputs, powerConnected, batteryOk, antenna, memories, updatedAt];
}
