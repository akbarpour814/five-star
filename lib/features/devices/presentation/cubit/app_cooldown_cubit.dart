import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/device_repository.dart';
import '../../domain/usecases/send_device_command.dart';

class AppCooldownState extends Equatable {
  const AppCooldownState({this.remaining = Duration.zero, this.deviceName, this.showName = false});

  /// Longest remaining wait among all devices.
  final Duration remaining;
  final String? deviceName;

  /// True when more than one device is registered, so the bubble names the device.
  final bool showName;

  bool get active => remaining > Duration.zero;

  @override
  List<Object?> get props => [remaining, deviceName, showName];
}

/// App-wide view of the two-minute SMS gap, driving the floating countdown bubble.
class AppCooldownCubit extends Cubit<AppCooldownState> {
  AppCooldownCubit({required this._repository, required this._sendCommand}) : super(const AppCooldownState()) {
    _subscription = _repository.changes.listen((_) => refresh());
    refresh();
  }

  final DeviceRepository _repository;
  final SendDeviceCommand _sendCommand;
  late final StreamSubscription<String> _subscription;
  Timer? _ticker;

  Future<void> refresh() async {
    final devices = await _repository.getDevices();
    var longest = Duration.zero;
    String? name;
    for (final device in devices) {
      final left = await _sendCommand.remainingCooldown(device.id);
      if (left > longest) {
        longest = left;
        name = device.name;
      }
    }
    if (isClosed) return;
    emit(AppCooldownState(remaining: longest, deviceName: name, showName: devices.length > 1));
    if (longest > Duration.zero) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
