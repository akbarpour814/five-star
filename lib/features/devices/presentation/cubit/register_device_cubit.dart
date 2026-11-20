import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../auth/domain/auth_repository.dart';
import '../../../gsa212/domain/gsa212_commands.dart';
import '../../domain/entities/device.dart';
import '../../domain/repositories/device_repository.dart';
import '../../domain/usecases/send_device_command.dart';

enum RegisterStep { device, pin, confirmPin, security }

class DeviceDraft extends Equatable {
  const DeviceDraft({
    required this.name,
    required this.simNumber,
    required this.password,
    this.ownerPhone = '',
    this.saveOwnerToMemory = true,
  });

  final String name;
  final String simNumber;
  final String password;
  final String ownerPhone;
  final bool saveOwnerToMemory;

  @override
  List<Object?> get props => [name, simNumber, password, ownerPhone, saveOwnerToMemory];
}

class RegisterState extends Equatable {
  const RegisterState({
    required this.withAppSecurity,
    this.step = RegisterStep.device,
    this.draft,
    this.pin = '',
    this.pinMismatchTick = 0,
    this.biometricAvailable = false,
    this.enableBiometric = false,
    this.submitting = false,
    this.result,
  });

  /// True during first-run onboarding: also creates the app PIN and biometric setting.
  final bool withAppSecurity;
  final RegisterStep step;
  final DeviceDraft? draft;
  final String pin;
  final int pinMismatchTick;
  final bool biometricAvailable;
  final bool enableBiometric;
  final bool submitting;
  final RegisterResult? result;

  List<RegisterStep> get steps => withAppSecurity ? RegisterStep.values : const [RegisterStep.device];

  RegisterState copyWith({
    RegisterStep? step,
    DeviceDraft? draft,
    String? pin,
    int? pinMismatchTick,
    bool? biometricAvailable,
    bool? enableBiometric,
    bool? submitting,
    RegisterResult? result,
  }) => RegisterState(
    withAppSecurity: withAppSecurity,
    step: step ?? this.step,
    draft: draft ?? this.draft,
    pin: pin ?? this.pin,
    pinMismatchTick: pinMismatchTick ?? this.pinMismatchTick,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    enableBiometric: enableBiometric ?? this.enableBiometric,
    submitting: submitting ?? this.submitting,
    result: result ?? this.result,
  );

  @override
  List<Object?> get props => [
    withAppSecurity,
    step,
    draft,
    pin,
    pinMismatchTick,
    biometricAvailable,
    enableBiometric,
    submitting,
    result,
  ];
}

class RegisterResult extends Equatable {
  const RegisterResult({required this.device, this.registrationSms});

  final Device device;

  /// Outcome of saving the owner's number in memory 01, when requested.
  final SendOutcome? registrationSms;

  @override
  List<Object?> get props => [device, registrationSms?.status];
}

class RegisterDeviceCubit extends Cubit<RegisterState> {
  RegisterDeviceCubit({
    required bool withAppSecurity,
    required this._devices,
    required this._auth,
    required this._sendCommand,
  }) : super(RegisterState(withAppSecurity: withAppSecurity));

  final DeviceRepository _devices;
  final AuthRepository _auth;
  final SendDeviceCommand _sendCommand;

  Future<void> init() async {
    if (!state.withAppSecurity) return;
    final available = await _auth.isBiometricAvailable();
    if (!isClosed) emit(state.copyWith(biometricAvailable: available, enableBiometric: available));
  }

  Future<String?> validateSimNumber(String sim) async {
    final existing = await _devices.findBySender(sim);
    return existing == null ? null : 'این شماره قبلا برای دستگاه «${existing.name}» ثبت شده است';
  }

  void submitDevice(DeviceDraft draft) {
    emit(state.copyWith(draft: draft));
    if (state.withAppSecurity) {
      emit(state.copyWith(step: RegisterStep.pin));
    } else {
      finish();
    }
  }

  void submitPin(String pin) => emit(state.copyWith(pin: pin, step: RegisterStep.confirmPin));

  void confirmPin(String pin) {
    if (pin == state.pin) {
      emit(state.copyWith(step: RegisterStep.security));
    } else {
      emit(state.copyWith(pin: '', step: RegisterStep.pin, pinMismatchTick: state.pinMismatchTick + 1));
    }
  }

  void setBiometric(bool enabled) => emit(state.copyWith(enableBiometric: enabled));

  void back() {
    final index = state.steps.indexOf(state.step);
    if (index <= 0) return;
    final previous = state.steps[index - 1];
    emit(state.copyWith(step: previous == RegisterStep.confirmPin ? RegisterStep.pin : previous, pin: ''));
  }

  Future<void> finish() async {
    final draft = state.draft;
    if (draft == null || state.submitting) return;
    emit(state.copyWith(submitting: true));

    final device = Device(
      id: IdGenerator.next(),
      name: draft.name.trim(),
      simNumber: PhoneUtils.normalize(draft.simNumber),
      ownerPhone: draft.ownerPhone.trim().isEmpty ? null : PhoneUtils.normalize(draft.ownerPhone),
      createdAt: DateTime.now(),
    );
    await _devices.saveDevice(device, password: draft.password);

    if (state.withAppSecurity) {
      await _auth.setPin(state.pin);
      var biometric = false;
      if (state.enableBiometric && state.biometricAvailable) {
        biometric = await _auth.authenticateWithBiometric();
      }
      await _auth.setBiometricEnabled(biometric);
    }

    SendOutcome? outcome;
    if (draft.saveOwnerToMemory && device.ownerPhone != null) {
      final command = Gsa212Commands(draft.password).saveNumber(memory: 1, phone: device.ownerPhone!);
      outcome = await _sendCommand(device, command);
    }
    if (!isClosed) {
      emit(
        state.copyWith(
          submitting: false,
          result: RegisterResult(device: device, registrationSms: outcome),
        ),
      );
    }
  }
}
