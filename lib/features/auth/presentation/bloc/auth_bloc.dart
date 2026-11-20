import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/auth_repository.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthPinSubmitted extends AuthEvent {
  const AuthPinSubmitted(this.pin);

  final String pin;

  @override
  List<Object?> get props => [pin];
}

final class AuthBiometricRequested extends AuthEvent {
  const AuthBiometricRequested();
}

final class AuthLockRequested extends AuthEvent {
  const AuthLockRequested();
}

final class AuthRegistered extends AuthEvent {
  const AuthRegistered();
}

final class AuthBiometricToggled extends AuthEvent {
  const AuthBiometricToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

final class AuthResetRequested extends AuthEvent {
  const AuthResetRequested();
}

enum AuthStatus { initial, unregistered, locked, unlocked }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
    this.failedAttempts = 0,
    this.errorTick = 0,
    this.lockedUntil,
    this.busy = false,
  });

  final AuthStatus status;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final int failedAttempts;

  /// Incremented on each wrong PIN so the UI can react (shake) even for repeated failures.
  final int errorTick;
  final DateTime? lockedUntil;
  final bool busy;

  bool get canUseBiometric => biometricAvailable && biometricEnabled;

  AuthState copyWith({
    AuthStatus? status,
    bool? biometricAvailable,
    bool? biometricEnabled,
    int? failedAttempts,
    int? errorTick,
    DateTime? Function()? lockedUntil,
    bool? busy,
  }) => AuthState(
    status: status ?? this.status,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    errorTick: errorTick ?? this.errorTick,
    lockedUntil: lockedUntil == null ? this.lockedUntil : lockedUntil(),
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [
    status,
    biometricAvailable,
    biometricEnabled,
    failedAttempts,
    errorTick,
    lockedUntil,
    busy,
  ];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this._repository, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthPinSubmitted>(_onPinSubmitted);
    on<AuthBiometricRequested>(_onBiometric);
    on<AuthLockRequested>(_onLock);
    on<AuthRegistered>(_onRegistered);
    on<AuthBiometricToggled>(_onBiometricToggled);
    on<AuthResetRequested>(_onReset);
  }

  static const maxAttempts = 5;
  static const lockoutDuration = Duration(seconds: 30);

  final AuthRepository _repository;
  final DateTime Function() _clock;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final registered = await _repository.isRegistered();
    emit(
      state.copyWith(
        status: registered ? AuthStatus.locked : AuthStatus.unregistered,
        biometricAvailable: await _repository.isBiometricAvailable(),
        biometricEnabled: await _repository.isBiometricEnabled(),
      ),
    );
  }

  Future<void> _onPinSubmitted(AuthPinSubmitted event, Emitter<AuthState> emit) async {
    final until = state.lockedUntil;
    if (until != null && _clock().isBefore(until)) return;

    if (await _repository.verifyPin(event.pin)) {
      emit(state.copyWith(status: AuthStatus.unlocked, failedAttempts: 0, lockedUntil: () => null));
      return;
    }
    final attempts = state.failedAttempts + 1;
    final lock = attempts >= maxAttempts;
    emit(
      state.copyWith(
        failedAttempts: lock ? 0 : attempts,
        errorTick: state.errorTick + 1,
        lockedUntil: () => lock ? _clock().add(lockoutDuration) : null,
      ),
    );
  }

  Future<void> _onBiometric(AuthBiometricRequested event, Emitter<AuthState> emit) async {
    if (!state.canUseBiometric || state.busy || state.status != AuthStatus.locked) return;
    emit(state.copyWith(busy: true));
    final ok = await _repository.authenticateWithBiometric();
    emit(
      state.copyWith(
        busy: false,
        status: ok ? AuthStatus.unlocked : state.status,
        failedAttempts: ok ? 0 : state.failedAttempts,
      ),
    );
  }

  void _onLock(AuthLockRequested event, Emitter<AuthState> emit) {
    if (state.status == AuthStatus.unlocked) emit(state.copyWith(status: AuthStatus.locked));
  }

  Future<void> _onRegistered(AuthRegistered event, Emitter<AuthState> emit) async {
    emit(
      state.copyWith(
        status: AuthStatus.unlocked,
        biometricEnabled: await _repository.isBiometricEnabled(),
        failedAttempts: 0,
        lockedUntil: () => null,
      ),
    );
  }

  Future<void> _onBiometricToggled(AuthBiometricToggled event, Emitter<AuthState> emit) async {
    if (event.enabled && !await _repository.authenticateWithBiometric()) return;
    await _repository.setBiometricEnabled(event.enabled);
    emit(state.copyWith(biometricEnabled: event.enabled));
  }

  Future<void> _onReset(AuthResetRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(busy: true));
    await _repository.resetApp();
    emit(AuthState(status: AuthStatus.unregistered, biometricAvailable: state.biometricAvailable));
  }
}
