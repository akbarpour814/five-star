import 'dart:async';

import '../../../../core/platform/sms_gateway.dart';
import '../../../gsa212/domain/gsa212_response_parser.dart';
import '../entities/device.dart';
import '../repositories/device_repository.dart';
import 'process_device_reply.dart';

class IncomingReply {
  const IncomingReply(this.device, this.response);

  final Device device;
  final ParsedResponse response;
}

/// Routes automatically received SMS (Android) to the device that sent them.
class IncomingSmsCoordinator {
  IncomingSmsCoordinator({required this._gateway, required this._repository, required this._processReply});

  final SmsGateway _gateway;
  final DeviceRepository _repository;
  final ProcessDeviceReply _processReply;
  final _replies = StreamController<IncomingReply>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void>? _draining;

  Stream<IncomingReply> get replies => _replies.stream;

  Future<void> start() async {
    if (!_gateway.receivesAutomatically || _subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(_gateway.incomingSignals.listen((_) => drain()))
      ..add(_repository.changes.listen((_) => syncWatchedNumbers()));
    await syncWatchedNumbers();
    await drain();
  }

  Future<void> syncWatchedNumbers() async {
    final devices = await _repository.getDevices();
    await _gateway.watchNumbers([for (final d in devices) d.simNumber]);
  }

  Future<void> drain() => _draining ??= _drain().whenComplete(() => _draining = null);

  Future<void> _drain() async {
    final pending = await _gateway.drainPending();
    for (final sms in pending) {
      final device = await _repository.findBySender(sms.sender);
      if (device == null) continue;
      final parsed = await _processReply(device.id, sms.body, at: sms.receivedAt);
      _replies.add(IncomingReply(device, parsed));
    }
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }
}
