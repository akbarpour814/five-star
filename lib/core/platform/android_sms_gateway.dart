import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sms_gateway.dart';

/// Android: sends through SmsManager and receives through a manifest SMS receiver.
/// Only checks permissions; the UI explains and requests them before calling in.
class AndroidSmsGateway implements SmsGateway {
  AndroidSmsGateway({
    MethodChannel methodChannel = const MethodChannel('fivestar/sms'),
    EventChannel eventChannel = const EventChannel('fivestar/sms_events'),
  }) : _method = methodChannel,
       _events = eventChannel;

  final MethodChannel _method;
  final EventChannel _events;

  @override
  bool get sendsDirectly => true;

  @override
  bool get receivesAutomatically => true;

  @override
  bool get supportsSimSelection => true;

  @override
  Future<List<SimCard>?> simCards() async {
    if (!await Permission.phone.isGranted) return null;
    try {
      final raw = await _method.invokeListMethod<Object?>('simCards') ?? const [];
      final cards = {
        for (final item in raw.whereType<Map<Object?, Object?>>())
          (item['slot'] as num).toInt(): SimCard(
            slot: (item['slot'] as num).toInt(),
            active: true,
            carrier: _blankToNull(item['carrier']),
            number: _blankToNull(item['number']),
          ),
      };
      return [for (var slot = 0; slot < 2; slot++) cards[slot] ?? SimCard(slot: slot)];
    } on PlatformException {
      return null;
    }
  }

  static String? _blankToNull(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  @override
  Future<SmsSendResult> send({required String number, required String body, int? simSlot}) async {
    if (!await Permission.sms.isGranted) return SmsSendResult.permissionDenied;
    if (simSlot != null && !await Permission.phone.isGranted) return SmsSendResult.permissionDenied;
    try {
      final ok = await _method.invokeMethod<bool>('send', {'number': number, 'body': body, 'slot': simSlot});
      return ok == true ? SmsSendResult.sent : SmsSendResult.failed;
    } on PlatformException catch (e) {
      return e.code == 'SIM_NOT_FOUND' ? SmsSendResult.simUnavailable : SmsSendResult.failed;
    }
  }

  @override
  Stream<void> get incomingSignals => _events.receiveBroadcastStream().map((_) {});

  @override
  Future<List<IncomingSms>> drainPending() async {
    final raw = await _method.invokeListMethod<Object?>('drainPending') ?? const [];
    return [
      for (final item in raw)
        if (item is Map)
          IncomingSms(
            sender: '${item['sender'] ?? ''}',
            body: '${item['body'] ?? ''}',
            receivedAt: DateTime.fromMillisecondsSinceEpoch((item['timestamp'] as num?)?.toInt() ?? 0),
          ),
    ];
  }

  @override
  Future<void> watchNumbers(List<String> numbers) => _method.invokeMethod<void>('watchNumbers', {'numbers': numbers});

  @override
  Future<void> clear() => _method.invokeMethod<void>('clear');
}
