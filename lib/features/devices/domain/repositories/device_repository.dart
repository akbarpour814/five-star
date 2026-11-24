import '../entities/device.dart';
import '../entities/device_message.dart';
import '../entities/device_status.dart';

abstract interface class DeviceRepository {
  /// Emits the id of a device whose data changed.
  Stream<String> get changes;

  Future<List<Device>> getDevices();

  Future<Device?> getDevice(String id);

  Future<Device?> findBySender(String number);

  Future<void> saveDevice(Device device, {String? password});

  Future<void> deleteDevice(String id);

  Future<String> getPassword(String deviceId);

  Future<void> setPassword(String deviceId, String password);

  /// Control passwords of partition parts 1–4 that were set from this app.
  Future<Map<int, String>> getPartPasswords(String deviceId);

  Future<void> setPartPassword(String deviceId, int part, String password);

  Future<DeviceStatus> getStatus(String deviceId);

  Future<void> saveStatus(String deviceId, DeviceStatus status);

  Future<Map<String, Object?>> getConfig(String deviceId);

  /// With [at] (when the SMS or command behind [patch] happened), a key is only overwritten when no
  /// newer value was stored for it, so late-processed replies never roll a setting back.
  Future<void> mergeConfig(String deviceId, Map<String, Object?> patch, {DateTime? at});

  Future<List<DeviceMessage>> getMessages(String deviceId);

  Future<void> addMessage(String deviceId, DeviceMessage message);

  Future<void> clearMessages(String deviceId);

  /// Receive time of the newest phone-inbox message already imported for this device.
  /// Reset when the device's SIM number changes.
  Future<DateTime?> getInboxSyncedAt(String deviceId);

  Future<void> setInboxSyncedAt(String deviceId, DateTime at);

  Future<DateTime?> getLastSentAt(String deviceId);

  Future<void> setLastSentAt(String deviceId, DateTime at);

  Future<void> clearAll();
}
