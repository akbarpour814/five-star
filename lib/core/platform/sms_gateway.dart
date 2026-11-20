import 'package:equatable/equatable.dart';

enum SmsSendResult { sent, openedComposer, permissionDenied, simUnavailable, failed }

class IncomingSms extends Equatable {
  const IncomingSms({required this.sender, required this.body, required this.receivedAt});

  final String sender;
  final String body;
  final DateTime receivedAt;

  @override
  List<Object?> get props => [sender, body, receivedAt];
}

/// One physical SIM slot of the phone; [slot] is zero-based.
class SimCard extends Equatable {
  const SimCard({required this.slot, this.active = false, this.carrier, this.number});

  final int slot;
  final bool active;
  final String? carrier;
  final String? number;

  @override
  List<Object?> get props => [slot, active, carrier, number];
}

abstract interface class SmsGateway {
  /// True when the app sends SMS itself (Android) instead of opening the messaging app.
  bool get sendsDirectly;

  /// True when device replies are picked up automatically (Android).
  bool get receivesAutomatically;

  /// True when the user can choose which SIM sends commands (Android).
  bool get supportsSimSelection;

  /// [simSlot] is zero-based; null uses the phone's default SMS SIM.
  Future<SmsSendResult> send({required String number, required String body, int? simSlot});

  /// Both SIM slots with whatever details the phone exposes; null when the phone permission is denied.
  Future<List<SimCard>?> simCards();

  /// Emits whenever new device replies are waiting in [drainPending].
  Stream<void> get incomingSignals;

  Future<List<IncomingSms>> drainPending();

  Future<void> watchNumbers(List<String> numbers);

  Future<void> clear();
}
