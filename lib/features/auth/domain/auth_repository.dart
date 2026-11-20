abstract interface class AuthRepository {
  Future<bool> isRegistered();

  Future<void> setPin(String pin);

  Future<bool> verifyPin(String pin);

  Future<bool> isBiometricEnabled();

  Future<void> setBiometricEnabled(bool enabled);

  Future<bool> isBiometricAvailable();

  Future<bool> authenticateWithBiometric();

  /// Wipes every piece of local data so the app starts from onboarding.
  Future<void> resetApp();
}
