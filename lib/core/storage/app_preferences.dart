import 'key_value_store.dart';

/// User-adjustable app settings that are not tied to a device.
class AppPreferences {
  AppPreferences(this._store);

  static const _smsIntervalKey = 'sms_interval_seconds';
  static const defaultSmsInterval = Duration(seconds: 20);
  static const smsIntervalOptions = [10, 20, 30, 60, 120];

  final KeyValueStore _store;

  /// Minimum gap between two SMS sent to the same device.
  Duration get smsInterval => Duration(seconds: _store.getInt(_smsIntervalKey) ?? defaultSmsInterval.inSeconds);

  Future<void> setSmsInterval(Duration value) => _store.setInt(_smsIntervalKey, value.inSeconds);
}
