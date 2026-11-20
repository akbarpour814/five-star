import 'dart:async';

import '../../../core/storage/key_value_store.dart';
import '../../../core/utils/phone_utils.dart';
import '../domain/entities/device.dart';
import '../domain/entities/device_message.dart';
import '../domain/entities/device_status.dart';
import '../domain/repositories/device_repository.dart';

class LocalDeviceRepository implements DeviceRepository {
  LocalDeviceRepository({required this._store, required this._secure});

  static const defaultPassword = '0000';
  static const _devicesKey = 'devices';
  static const _maxMessages = 300;

  final KeyValueStore _store;
  final SecureStore _secure;
  final _changes = StreamController<String>.broadcast();

  static String _statusKey(String id) => 'status_$id';
  static String _configKey(String id) => 'config_$id';
  static String _messagesKey(String id) => 'messages_$id';
  static String _lastSentKey(String id) => 'last_sent_$id';
  static String _passwordKey(String id) => 'device_password_$id';

  @override
  Stream<String> get changes => _changes.stream;

  void _notify(String id) => _changes.add(id);

  @override
  Future<List<Device>> getDevices() async {
    final raw = _store.getJson(_devicesKey);
    if (raw is! List) return [];
    return [for (final item in raw) Device.fromJson(Map<String, dynamic>.from(item as Map))];
  }

  @override
  Future<Device?> getDevice(String id) async {
    for (final d in await getDevices()) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<Device?> findBySender(String number) async {
    for (final d in await getDevices()) {
      if (PhoneUtils.same(d.simNumber, number)) return d;
    }
    return null;
  }

  @override
  Future<void> saveDevice(Device device, {String? password}) async {
    final devices = await getDevices();
    final index = devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }
    await _store.setJson(_devicesKey, [for (final d in devices) d.toJson()]);
    if (password != null) await _secure.write(_passwordKey(device.id), password);
    _notify(device.id);
  }

  @override
  Future<void> deleteDevice(String id) async {
    final devices = await getDevices()
      ..removeWhere((d) => d.id == id);
    await _store.setJson(_devicesKey, [for (final d in devices) d.toJson()]);
    await Future.wait([
      _store.remove(_statusKey(id)),
      _store.remove(_configKey(id)),
      _store.remove(_messagesKey(id)),
      _store.remove(_lastSentKey(id)),
      _secure.delete(_passwordKey(id)),
    ]);
    _notify(id);
  }

  @override
  Future<String> getPassword(String deviceId) async => await _secure.read(_passwordKey(deviceId)) ?? defaultPassword;

  @override
  Future<void> setPassword(String deviceId, String password) async {
    await _secure.write(_passwordKey(deviceId), password);
    _notify(deviceId);
  }

  @override
  Future<DeviceStatus> getStatus(String deviceId) async {
    final raw = _store.getJson(_statusKey(deviceId));
    return raw is Map ? DeviceStatus.fromJson(Map<String, dynamic>.from(raw)) : DeviceStatus.empty;
  }

  @override
  Future<void> saveStatus(String deviceId, DeviceStatus status) async {
    await _store.setJson(_statusKey(deviceId), status.toJson());
    _notify(deviceId);
  }

  @override
  Future<Map<String, Object?>> getConfig(String deviceId) async {
    final raw = _store.getJson(_configKey(deviceId));
    return raw is Map ? Map<String, Object?>.from(raw) : {};
  }

  @override
  Future<void> mergeConfig(String deviceId, Map<String, Object?> patch) async {
    if (patch.isEmpty) return;
    final config = await getConfig(deviceId)
      ..addAll(patch);
    await _store.setJson(_configKey(deviceId), config);
    _notify(deviceId);
  }

  @override
  Future<List<DeviceMessage>> getMessages(String deviceId) async {
    final raw = _store.getJson(_messagesKey(deviceId));
    if (raw is! List) return [];
    return [for (final item in raw) DeviceMessage.fromJson(Map<String, dynamic>.from(item as Map))];
  }

  @override
  Future<void> addMessage(String deviceId, DeviceMessage message) async {
    final messages = await getMessages(deviceId)
      ..add(message);
    final trimmed = messages.length > _maxMessages ? messages.sublist(messages.length - _maxMessages) : messages;
    await _store.setJson(_messagesKey(deviceId), [for (final m in trimmed) m.toJson()]);
    _notify(deviceId);
  }

  @override
  Future<void> clearMessages(String deviceId) async {
    await _store.remove(_messagesKey(deviceId));
    _notify(deviceId);
  }

  @override
  Future<DateTime?> getLastSentAt(String deviceId) async {
    final ms = _store.getInt(_lastSentKey(deviceId));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> setLastSentAt(String deviceId, DateTime at) async {
    await _store.setInt(_lastSentKey(deviceId), at.millisecondsSinceEpoch);
    _notify(deviceId);
  }

  @override
  Future<void> clearAll() async {
    final devices = await getDevices();
    for (final d in devices) {
      await _secure.delete(_passwordKey(d.id));
    }
    await _store.clear();
    for (final d in devices) {
      _notify(d.id);
    }
  }
}
