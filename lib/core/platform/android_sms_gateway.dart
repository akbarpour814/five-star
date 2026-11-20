import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'composer_sms_gateway.dart';
import 'sms_gateway.dart';

/// Android: sends through SmsManager and receives through a manifest SMS receiver.
class AndroidSmsGateway implements SmsGateway {
  AndroidSmsGateway({
    MethodChannel methodChannel = const MethodChannel('fivestar/sms'),
    EventChannel eventChannel = const EventChannel('fivestar/sms_events'),
    this._fallback = const ComposerSmsGateway(),
  }) : _method = methodChannel,
       _events = eventChannel;

  final MethodChannel _method;
  final EventChannel _events;
  final SmsGateway _fallback;

  @override
  bool get sendsDirectly => true;

  @override
  bool get receivesAutomatically => true;

  @override
  Future<bool> ensurePermissions() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  @override
  Future<SmsSendResult> send({required String number, required String body}) async {
    if (!await ensurePermissions()) {
      final result = await _fallback.send(number: number, body: body);
      return result == SmsSendResult.openedComposer ? result : SmsSendResult.permissionDenied;
    }
    try {
      final ok = await _method.invokeMethod<bool>('send', {'number': number, 'body': body});
      return ok == true ? SmsSendResult.sent : SmsSendResult.failed;
    } on PlatformException {
      return SmsSendResult.failed;
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
