import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../panel/domain/device_command.dart';
import '../../../panel/domain/device_model.dart';
import '../../../panel/domain/panel_commands.dart';
import '../../../panel/domain/panel_response_parser.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/device_message.dart';
import '../../domain/entities/device_status.dart';
import '../../domain/repositories/device_repository.dart';
import '../../domain/usecases/process_device_reply.dart';
import '../../domain/usecases/send_device_command.dart';

class DeviceState extends Equatable {
  const DeviceState({
    required this.device,
    this.status = DeviceStatus.empty,
    this.config = const {},
    this.messages = const [],
    this.password = '0000',
    this.partPasswords = const {},
    this.cooldown = Duration.zero,
    this.sending = false,
    this.deleted = false,
  });

  final Device device;
  final DeviceStatus status;
  final Map<String, Object?> config;

  /// Oldest first.
  final List<DeviceMessage> messages;
  final String password;

  /// Part (1–4) control passwords saved when they were changed from the app.
  final Map<int, String> partPasswords;
  final Duration cooldown;
  final bool sending;
  final bool deleted;

  bool get canSend => cooldown == Duration.zero && !sending;

  bool get usesDefaultPassword => password == '0000';

  DeviceModel get model => device.type;

  PanelCommands get commands => PanelCommands(model, password);

  bool has(DeviceFeature feature) => model.has(feature);

  T? configValue<T>(String key) {
    final value = config[key];
    return value is T ? value : null;
  }

  DeviceState copyWith({
    Device? device,
    DeviceStatus? status,
    Map<String, Object?>? config,
    List<DeviceMessage>? messages,
    String? password,
    Map<int, String>? partPasswords,
    Duration? cooldown,
    bool? sending,
    bool? deleted,
  }) => DeviceState(
    device: device ?? this.device,
    status: status ?? this.status,
    config: config ?? this.config,
    messages: messages ?? this.messages,
    password: password ?? this.password,
    partPasswords: partPasswords ?? this.partPasswords,
    cooldown: cooldown ?? this.cooldown,
    sending: sending ?? this.sending,
    deleted: deleted ?? this.deleted,
  );

  @override
  List<Object?> get props => [device, status, config, messages, password, partPasswords, cooldown, sending, deleted];
}

class DeviceCubit extends Cubit<DeviceState> {
  DeviceCubit({
    required Device device,
    required this._repository,
    required this._sendCommand,
    required this._processReply,
  }) : super(DeviceState(device: device)) {
    _subscription = _repository.changes.where((id) => id == device.id).listen((_) => load());
  }

  final DeviceRepository _repository;
  final SendDeviceCommand _sendCommand;
  final ProcessDeviceReply _processReply;
  late final StreamSubscription<String> _subscription;
  Timer? _ticker;

  Future<void> load() async {
    final id = state.device.id;
    final device = await _repository.getDevice(id);
    if (device == null) {
      if (!isClosed) emit(state.copyWith(deleted: true));
      return;
    }
    final next = state.copyWith(
      device: device,
      status: await _repository.getStatus(id),
      config: await _repository.getConfig(id),
      messages: await _repository.getMessages(id),
      password: await _repository.getPassword(id),
      partPasswords: await _repository.getPartPasswords(id),
    );
    if (isClosed) return;
    emit(next);
    await _refreshCooldown();
  }

  Future<void> _refreshCooldown() async {
    final left = await _sendCommand.remainingCooldown(state.device.id);
    if (isClosed) return;
    emit(state.copyWith(cooldown: left));
    _ticker?.cancel();
    if (left > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
        final remaining = await _sendCommand.remainingCooldown(state.device.id);
        if (isClosed) return;
        emit(state.copyWith(cooldown: remaining));
        if (remaining == Duration.zero) _ticker?.cancel();
      });
    }
  }

  Future<SendOutcome> send(DeviceCommand command) async {
    if (state.sending) return const SendOutcome(SendStatus.failed);
    emit(state.copyWith(sending: true));
    final outcome = await _sendCommand(state.device, command);
    if (isClosed) return outcome;
    emit(state.copyWith(sending: false));
    await _refreshCooldown();
    return outcome;
  }

  /// Sends a password change and, once dispatched, uses the new password for later commands.
  Future<SendOutcome> changePassword(String newPassword) async {
    final outcome = await send(state.commands.changePassword(newPassword));
    if (outcome.delivered) await _repository.setPassword(state.device.id, newPassword);
    return outcome;
  }

  ParsedResponse preview(String text) => _processReply.preview(text, model: state.model, config: state.config);

  Future<ParsedResponse> ingest(String text) => _processReply(state.device.id, text);

  Future<void> updateDevice({
    required String name,
    required String simNumber,
    String? ownerPhone,
    DeviceModel? model,
  }) => _repository.saveDevice(
    state.device.copyWith(name: name, simNumber: simNumber, ownerPhone: ownerPhone, model: model?.code),
  );

  Future<void> updateSimSlot(int slot) => _repository.saveDevice(state.device.copyWith(simSlot: slot));

  /// An empty [name] restores the default output name.
  Future<void> renameOutput(int output, String name) {
    final names = {...state.device.outputNames};
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      names.remove(output);
    } else {
      names[output] = trimmed;
    }
    return _repository.saveDevice(state.device.copyWith(outputNames: names));
  }

  /// Sends a part password change and remembers the new password for the part control tab.
  Future<SendOutcome> changePartPassword({
    required int part,
    required String oldPassword,
    required String newPassword,
  }) async {
    final outcome = await send(
      state.commands.partPasswordChange(part: part, oldPassword: oldPassword, newPassword: newPassword),
    );
    if (outcome.delivered) await _repository.setPartPassword(state.device.id, part, newPassword);
    return outcome;
  }

  Future<void> updatePassword(String password) => _repository.setPassword(state.device.id, password);

  Future<void> clearMessages() => _repository.clearMessages(state.device.id);

  Future<void> delete() => _repository.deleteDevice(state.device.id);

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
