import 'dart:async';

import '../../../../core/platform/sms_gateway.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../panel/domain/panel_response_parser.dart';
import '../entities/device.dart';
import '../repositories/device_repository.dart';
import 'process_device_reply.dart';

class IncomingReply {
  const IncomingReply(this.device, this.response);

  final Device device;
  final ParsedResponse response;
}

/// Routes automatically received SMS (Android) to the device that sent them, so the shown state
/// always follows the newest SMS of each device:
/// live while the app runs ([drain] on every receiver signal), and on start / resume / opening a
/// device ([refresh]) by also importing everything from the device numbers in the phone inbox.
class IncomingSmsCoordinator {
  IncomingSmsCoordinator({required this._gateway, required this._repository, required this._processReply});

  final SmsGateway _gateway;
  final DeviceRepository _repository;
  final ProcessDeviceReply _processReply;
  final _replies = StreamController<IncomingReply>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void>? _refreshing;

  /// Drain and inbox import run one after another so the same SMS is never processed twice concurrently.
  Future<void> _queue = Future.value();

  /// How far back a newly added device (or a changed SIM number) reads its inbox history, so the
  /// device starts with the state of its latest SMS instead of an empty one.
  static const initialLookback = Duration(days: 30);

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
      await _serial(_syncInbox);
    }().whenComplete(() => _refreshing = null);
  }

  Future<void> _serial(Future<void> Function() task) {
    final run = _queue.then((_) => task());
    _queue = run.catchError((Object _) {});
    return run;
  }

  /// Each device keeps its own cursor, so a device added later (or whose SIM number changed)
  /// still gets its inbox history instead of starting after other devices' last import.
  Future<void> _syncInbox() async {
    for (final device in await _repository.getDevices()) {
      final synced = await _repository.getInboxSyncedAt(device.id);
      final since = synced ?? device.createdAt.subtract(initialLookback);
      final inbox = await _gateway.readInbox(numbers: [device.simNumber], since: since);
      var newest = since;
      for (final sms in inbox) {
        if (sms.receivedAt.isAfter(newest)) newest = sms.receivedAt;
        if (await _alreadyStored(device.id, sms)) continue;
        await _processReply(device.id, sms.body, at: sms.receivedAt);
      }
      if (newest.isAfter(since)) await _repository.setInboxSyncedAt(device.id, newest);
    }
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

  String? _watched;

  /// Keeps the native receiver's sender filter current. A device added, or a SIM number changed,
  /// imports its inbox history right away so its latest state shows without reopening the app.
  Future<void> syncWatchedNumbers() async {
    final devices = await _repository.getDevices();
    final numbers = [for (final d in devices) '${d.id}:${d.simNumber}']..sort();
    final key = numbers.join(',');
    if (key == _watched) return;
    final first = _watched == null;
    _watched = key;
    await _gateway.watchNumbers([for (final d in devices) d.simNumber]);
    if (!first) unawaited(refresh());
  }

  Future<void> drain() => _serial(_drain);

  Future<void> _drain() async {
    final pending = await _gateway.drainPending();
    for (final sms in pending) {
      final device = await _repository.findBySender(sms.sender);
      if (device == null || await _alreadyStored(device.id, sms)) continue;
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
