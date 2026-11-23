import 'dart:async';

import '../../../../core/platform/sms_gateway.dart';
import '../../../../core/utils/text_normalizer.dart';
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
  Future<void>? _refreshing;

  Stream<IncomingReply> get replies => _replies.stream;

  Future<void> start() async {
    if (!_gateway.receivesAutomatically || _subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(_gateway.incomingSignals.listen((_) => drain()))
      ..add(_repository.changes.listen((_) => syncWatchedNumbers()));
    await syncWatchedNumbers();
    await refresh();
  }

  /// Run when the app opens or returns to the foreground: picks up queued replies, then
  /// imports anything from the device numbers that reached the inbox while the app was closed.
  Future<void> refresh() {
    if (!_gateway.receivesAutomatically) return Future.value();
    return _refreshing ??= () async {
      await drain();
      await _syncInbox();
    }().whenComplete(() => _refreshing = null);
  }

  Future<void> _syncInbox() async {
    final devices = await _repository.getDevices();
    if (devices.isEmpty) return;
    final earliest = devices.map((d) => d.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final synced = await _repository.getInboxSyncedAt();
    final since = synced == null || synced.isBefore(earliest) ? earliest : synced;

    final inbox = await _gateway.readInbox(numbers: [for (final d in devices) d.simNumber], since: since);
    var newest = since;
    for (final sms in inbox) {
      if (sms.receivedAt.isAfter(newest)) newest = sms.receivedAt;
      final device = await _repository.findBySender(sms.sender);
      if (device == null || sms.receivedAt.isBefore(device.createdAt)) continue;
      if (await _alreadyStored(device.id, sms)) continue;
      await _processReply(device.id, sms.body, at: sms.receivedAt);
    }
    if (newest.isAfter(since)) await _repository.setInboxSyncedAt(newest);
  }

  /// The SMS receiver may already have logged this message; its timestamp can differ slightly from the inbox one.
  Future<bool> _alreadyStored(String deviceId, IncomingSms sms) async {
    final body = TextNormalizer.compact(sms.body);
    for (final m in await _repository.getMessages(deviceId)) {
      if (m.isIncoming &&
          m.at.difference(sms.receivedAt).abs() <= const Duration(minutes: 3) &&
          TextNormalizer.compact(m.body) == body) {
        return true;
      }
    }
    return false;
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
