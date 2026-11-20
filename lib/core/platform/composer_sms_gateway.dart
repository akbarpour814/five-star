import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sms_gateway.dart';

/// iOS / web: hands the command to the system messaging app; replies are pasted by the user.
class ComposerSmsGateway implements SmsGateway {
  const ComposerSmsGateway();

  @override
  bool get sendsDirectly => false;

  @override
  bool get receivesAutomatically => false;

  static Uri buildUri(String number, String body, {TargetPlatform? platform}) {
    final encoded = Uri.encodeComponent(body);
    final separator =
        (platform ?? defaultTargetPlatform) == TargetPlatform.iOS ||
            (platform ?? defaultTargetPlatform) == TargetPlatform.macOS
        ? '&'
        : '?';
    return Uri.parse('sms:$number${separator}body=$encoded');
  }

  @override
  Future<SmsSendResult> send({required String number, required String body}) async {
    try {
      final opened = await launchUrl(buildUri(number, body), mode: LaunchMode.externalApplication);
      return opened ? SmsSendResult.openedComposer : SmsSendResult.failed;
    } on Exception {
      return SmsSendResult.failed;
    }
  }

  @override
  Stream<void> get incomingSignals => const Stream.empty();

  @override
  Future<List<IncomingSms>> drainPending() async => const [];

  @override
  Future<void> watchNumbers(List<String> numbers) async {}

  @override
  Future<bool> ensurePermissions() async => true;

  @override
  Future<void> clear() async {}
}
