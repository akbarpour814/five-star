import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/local_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/devices/data/local_device_repository.dart';
import '../../features/devices/domain/repositories/device_repository.dart';
import '../../features/devices/domain/usecases/incoming_sms_coordinator.dart';
import '../../features/devices/domain/usecases/process_device_reply.dart';
import '../../features/devices/domain/usecases/send_device_command.dart';
import '../permissions/permission_service.dart';
import '../platform/android_sms_gateway.dart';
import '../platform/composer_sms_gateway.dart';
import '../platform/sms_gateway.dart';
import '../storage/key_value_store.dart';

final sl = GetIt.instance;

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  sl
    ..registerLazySingleton(() => KeyValueStore(prefs))
    ..registerLazySingleton(SecureStore.new)
    ..registerLazySingleton(() => const PermissionService())
    ..registerLazySingleton<SmsGateway>(() => _isAndroid ? AndroidSmsGateway() : const ComposerSmsGateway())
    ..registerLazySingleton<DeviceRepository>(() => LocalDeviceRepository(store: sl(), secure: sl()))
    ..registerLazySingleton<AuthRepository>(
      () => LocalAuthRepository(secure: sl(), store: sl(), devices: sl(), gateway: sl()),
    )
    ..registerLazySingleton(() => SendDeviceCommand(repository: sl(), gateway: sl()))
    ..registerLazySingleton(() => ProcessDeviceReply(repository: sl()))
    ..registerLazySingleton(() => IncomingSmsCoordinator(gateway: sl(), repository: sl(), processReply: sl()));
}
