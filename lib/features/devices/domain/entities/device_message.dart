import 'package:equatable/equatable.dart';

enum MessageDirection { outgoing, incoming }

enum MessageSeverity { info, success, alert }

class DeviceMessage extends Equatable {
  const DeviceMessage({
    required this.id,
    required this.direction,
    required this.title,
    required this.body,
    required this.at,
    this.detail,
    this.severity = MessageSeverity.info,
  });

  factory DeviceMessage.fromJson(Map<String, dynamic> json) => DeviceMessage(
    id: json['id'] as String,
    direction: MessageDirection.values.byName(json['direction'] as String),
    title: json['title'] as String,
    body: json['body'] as String,
    detail: json['detail'] as String?,
    severity: MessageSeverity.values.asNameMap()[json['severity']] ?? MessageSeverity.info,
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
  );

  final String id;
  final MessageDirection direction;
  final String title;

  /// Outgoing: masked command text. Incoming: raw device reply.
  final String body;
  final String? detail;
  final MessageSeverity severity;
  final DateTime at;

  bool get isIncoming => direction == MessageDirection.incoming;

  Map<String, dynamic> toJson() => {
    'id': id,
    'direction': direction.name,
    'title': title,
    'body': body,
    'detail': detail,
    'severity': severity.name,
    'at': at.millisecondsSinceEpoch,
  };

  @override
  List<Object?> get props => [id, direction, title, body, detail, severity, at];
}
