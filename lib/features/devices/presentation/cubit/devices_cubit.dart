import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/device.dart';
import '../../domain/entities/device_message.dart';
import '../../domain/entities/device_status.dart';
import '../../domain/repositories/device_repository.dart';

class DeviceOverview extends Equatable {
  const DeviceOverview({required this.device, required this.status, this.lastMessage});

  final Device device;
  final DeviceStatus status;
  final DeviceMessage? lastMessage;

  @override
  List<Object?> get props => [device, status, lastMessage];
}

class DevicesState extends Equatable {
  const DevicesState({this.loading = true, this.items = const []});

  final bool loading;
  final List<DeviceOverview> items;

  @override
  List<Object?> get props => [loading, items];
}

class DevicesCubit extends Cubit<DevicesState> {
  DevicesCubit(this._repository) : super(const DevicesState()) {
    _subscription = _repository.changes.listen((_) => load());
  }

  final DeviceRepository _repository;
  late final StreamSubscription<String> _subscription;

  Future<void> load() async {
    final devices = await _repository.getDevices();
    final items = <DeviceOverview>[];
    for (final device in devices) {
      final messages = await _repository.getMessages(device.id);
      items.add(
        DeviceOverview(
          device: device,
          status: await _repository.getStatus(device.id),
          lastMessage: messages.isEmpty ? null : messages.last,
        ),
      );
    }
    if (!isClosed) emit(DevicesState(loading: false, items: items));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
