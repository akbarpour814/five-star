import 'package:equatable/equatable.dart';

import '../../../../core/utils/text_normalizer.dart';
import '../../../panel/domain/device_model.dart';

class Device extends Equatable {
  const Device({
    required this.id,
    required this.name,
    required this.simNumber,
    required this.createdAt,
    this.ownerPhone,
    this.model = DeviceModel.fallbackCode,
    this.simSlot,
    this.outputNames = const {},
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as String,
    name: json['name'] as String,
    simNumber: json['simNumber'] as String,
    ownerPhone: json['ownerPhone'] as String?,
    model: json['model'] as String? ?? DeviceModel.fallbackCode,
    simSlot: json['simSlot'] as int?,
    outputNames: {
      for (final e in (json['outputNames'] as Map? ?? const {}).entries) int.parse('${e.key}'): '${e.value}',
    },
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
  );

  final String id;
  final String name;
  final String simNumber;
  final String? ownerPhone;

  /// Model code (e.g. `GSA-212`); see [type].
  final String model;
  final DateTime createdAt;

  /// Zero-based phone SIM slot used to send commands (Android); null means the default SMS SIM.
  final int? simSlot;

  /// User-given names for outputs 1–4; missing entries use the default name.
  final Map<int, String> outputNames;

  DeviceModel get type => DeviceModel.fromCode(model);

  /// Output 1 drives the door opener on models with the D command.
  String outputName(int output) =>
      outputNames[output] ??
      (output == 1 && type.has(DeviceFeature.openDoor)
          ? 'خروجی ۱ (درب‌بازکن)'
          : 'خروجی ${TextNormalizer.toPersianDigits(output)}');

  bool hasCustomOutputName(int output) => outputNames.containsKey(output);

  Device copyWith({
    String? name,
    String? simNumber,
    String? ownerPhone,
    String? model,
    int? simSlot,
    Map<int, String>? outputNames,
  }) => Device(
    id: id,
    name: name ?? this.name,
    simNumber: simNumber ?? this.simNumber,
    ownerPhone: ownerPhone ?? this.ownerPhone,
    model: model ?? this.model,
    createdAt: createdAt,
    simSlot: simSlot ?? this.simSlot,
    outputNames: outputNames ?? this.outputNames,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'simNumber': simNumber,
    'ownerPhone': ownerPhone,
    'model': model,
    'simSlot': simSlot,
    'outputNames': {for (final e in outputNames.entries) '${e.key}': e.value},
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  @override
  List<Object?> get props => [id, name, simNumber, ownerPhone, model, createdAt, simSlot, outputNames];
}
