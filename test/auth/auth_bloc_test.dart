import 'package:bloc_test/bloc_test.dart';
import 'package:five_star/features/auth/domain/auth_repository.dart';
import 'package:five_star/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  final now = DateTime(2026, 11, 20);

  setUp(() {
    repository = _MockAuthRepository();
    when(() => repository.isBiometricAvailable()).thenAnswer((_) async => true);
    when(() => repository.isBiometricEnabled()).thenAnswer((_) async => true);
    when(() => repository.verifyPin('1234')).thenAnswer((_) async => true);
    when(() => repository.verifyPin(any(that: isNot('1234')))).thenAnswer((_) async => false);
  });

  AuthBloc build() => AuthBloc(repository: repository, clock: () => now);

  blocTest<AuthBloc, AuthState>(
    'starts unregistered when no PIN exists',
    setUp: () => when(() => repository.isRegistered()).thenAnswer((_) async => false),
    build: build,
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const AuthState(status: AuthStatus.unregistered, biometricAvailable: true, biometricEnabled: true)],
  );

  blocTest<AuthBloc, AuthState>(
    'unlocks with the right PIN',
    build: build,
    seed: () => const AuthState(status: AuthStatus.locked),
    act: (bloc) => bloc.add(const AuthPinSubmitted('1234')),
    expect: () => [const AuthState(status: AuthStatus.unlocked)],
  );

  blocTest<AuthBloc, AuthState>(
    'locks out for 30 seconds after five wrong PINs',
    build: build,
    seed: () => const AuthState(status: AuthStatus.locked, failedAttempts: 4, errorTick: 4),
    act: (bloc) => bloc
      ..add(const AuthPinSubmitted('0000'))
      ..add(const AuthPinSubmitted('1234')),
    expect: () => [AuthState(status: AuthStatus.locked, errorTick: 5, lockedUntil: now.add(AuthBloc.lockoutDuration))],
  );

  blocTest<AuthBloc, AuthState>(
    'biometric success unlocks',
    setUp: () => when(() => repository.authenticateWithBiometric()).thenAnswer((_) async => true),
    build: build,
    seed: () => const AuthState(status: AuthStatus.locked, biometricAvailable: true, biometricEnabled: true),
    act: (bloc) => bloc.add(const AuthBiometricRequested()),
    expect: () => [
      const AuthState(status: AuthStatus.locked, biometricAvailable: true, biometricEnabled: true, busy: true),
      const AuthState(status: AuthStatus.unlocked, biometricAvailable: true, biometricEnabled: true),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'reset wipes data and returns to onboarding',
    setUp: () => when(() => repository.resetApp()).thenAnswer((_) async {}),
    build: build,
    seed: () => const AuthState(status: AuthStatus.locked, biometricAvailable: true, biometricEnabled: true),
    act: (bloc) => bloc.add(const AuthResetRequested()),
    expect: () => [
      const AuthState(status: AuthStatus.locked, biometricAvailable: true, biometricEnabled: true, busy: true),
      const AuthState(status: AuthStatus.unregistered, biometricAvailable: true),
    ],
    verify: (_) => verify(() => repository.resetApp()).called(1),
  );
}
