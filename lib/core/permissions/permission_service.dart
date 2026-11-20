import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions the app asks for. [biometric] has no OS status to query; it is only explained to the user.
enum AppPermission { sms, phone, biometric }

enum AppPermissionStatus { granted, denied, permanentlyDenied }

/// Checks and requests OS permissions. Never call [request] without first explaining it to the user.
class PermissionService {
  const PermissionService();

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Permission? _osPermission(AppPermission permission) => switch (permission) {
    AppPermission.sms => _android ? Permission.sms : null,
    AppPermission.phone => _android ? Permission.phone : null,
    AppPermission.biometric => null,
  };

  static AppPermissionStatus _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return AppPermissionStatus.granted;
    if (status.isPermanentlyDenied || status.isRestricted) return AppPermissionStatus.permanentlyDenied;
    return AppPermissionStatus.denied;
  }

  /// True when the permission has an OS prompt on this platform.
  bool hasSystemPrompt(AppPermission permission) => _osPermission(permission) != null;

  Future<AppPermissionStatus> status(AppPermission permission) async {
    final os = _osPermission(permission);
    return os == null ? AppPermissionStatus.granted : _map(await os.status);
  }

  Future<AppPermissionStatus> request(AppPermission permission) async {
    final os = _osPermission(permission);
    return os == null ? AppPermissionStatus.granted : _map(await os.request());
  }

  Future<bool> openSettings() => openAppSettings();
}
