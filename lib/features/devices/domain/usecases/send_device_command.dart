import '../../../../core/platform/sms_gateway.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../gsa212/domain/device_command.dart';
import '../../../gsa212/domain/gsa212_commands.dart';
import '../entities/device.dart';
import '../entities/device_message.dart';
import '../repositories/device_repository.dart';

enum SendStatus { sent, openedComposer, cooldown, permissionDenied, failed }

class SendOutcome {
  const SendOutcome(this.status, {this.wait = Duration.zero});

  final SendStatus status;
  final Duration wait;

  bool get delivered => status == SendStatus.sent || status == SendStatus.openedComposer;
}

/// Sends a command while enforcing the manual's two-minute gap between SMS to the device.
class SendDeviceCommand {
  SendDeviceCommand({required this._repository, required this._gateway, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DeviceRepository _repository;
  final SmsGateway _gateway;
  final DateTime Function() _clock;

  Future<Duration> remainingCooldown(String deviceId) async {
    final last = await _repository.getLastSentAt(deviceId);
    if (last == null) return Duration.zero;
    final left = Gsa212Commands.minInterval - _clock().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  Future<SendOutcome> call(Device device, DeviceCommand command) async {
    final wait = await remainingCooldown(device.id);
    if (wait > Duration.zero) return SendOutcome(SendStatus.cooldown, wait: wait);

    final result = await _gateway.send(number: device.simNumber, body: command.body);
    final status = switch (result) {
      SmsSendResult.sent => SendStatus.sent,
      SmsSendResult.openedComposer => SendStatus.openedComposer,
      SmsSendResult.permissionDenied => SendStatus.permissionDenied,
      SmsSendResult.failed => SendStatus.failed,
    };
    if (status != SendStatus.sent && status != SendStatus.openedComposer) return SendOutcome(status);

    final now = _clock();
    await _repository.setLastSentAt(device.id, now);
    await _repository.mergeConfig(device.id, command.configPatch);
    await _repository.addMessage(
      device.id,
      DeviceMessage(
        id: IdGenerator.next(),
        direction: MessageDirection.outgoing,
        title: command.title,
        body: command.maskedBody,
        detail: status == SendStatus.openedComposer ? 'ارسال از طریق پیام‌رسان' : null,
        at: now,
      ),
    );
    return SendOutcome(status);
  }
}
