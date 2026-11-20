import 'package:equatable/equatable.dart';

enum SmsSendResult { sent, openedComposer, permissionDenied, failed }

class IncomingSms extends Equatable {
  const IncomingSms({required this.sender, required this.body, required this.receivedAt});

  final String sender;
  final String body;
  final DateTime receivedAt;

  @override
  List<Object?> get props => [sender, body, receivedAt];
}

abstract interface class SmsGateway {
  /// True when the app sends SMS itself (Android) instead of opening the messaging app.
  bool get sendsDirectly;

  /// True when device replies are picked up automatically (Android).
  bool get receivesAutomatically;

  Future<SmsSendResult> send({required String number, required String body});

  /// Emits whenever new device replies are waiting in [drainPending].
  Stream<void> get incomingSignals;

  Future<List<IncomingSms>> drainPending();

  Future<void> watchNumbers(List<String> numbers);

  Future<bool> ensurePermissions();

  Future<void> clear();
}
