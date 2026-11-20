import 'package:equatable/equatable.dart';

class Device extends Equatable {
  const Device({
    required this.id,
    required this.name,
    required this.simNumber,
    required this.createdAt,
    this.ownerPhone,
    this.model = 'GSA-212',
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as String,
    name: json['name'] as String,
    simNumber: json['simNumber'] as String,
    ownerPhone: json['ownerPhone'] as String?,
    model: json['model'] as String? ?? 'GSA-212',
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
  );

  final String id;
  final String name;
  final String simNumber;
  final String? ownerPhone;
  final String model;
  final DateTime createdAt;

  Device copyWith({String? name, String? simNumber, String? ownerPhone}) => Device(
    id: id,
    name: name ?? this.name,
    simNumber: simNumber ?? this.simNumber,
    ownerPhone: ownerPhone ?? this.ownerPhone,
    model: model,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'simNumber': simNumber,
    'ownerPhone': ownerPhone,
    'model': model,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  @override
  List<Object?> get props => [id, name, simNumber, ownerPhone, model, createdAt];
}
