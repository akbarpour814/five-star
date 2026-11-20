import 'package:five_star/core/platform/sms_gateway.dart';
import 'package:five_star/core/storage/key_value_store.dart';
import 'package:five_star/features/devices/data/local_device_repository.dart';
import 'package:five_star/features/devices/domain/entities/device.dart';
import 'package:five_star/features/devices/domain/entities/device_message.dart';
import 'package:five_star/features/devices/domain/usecases/process_device_reply.dart';
import 'package:five_star/features/devices/domain/usecases/send_device_command.dart';
import 'package:five_star/features/gsa212/domain/gsa212_commands.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGateway extends Mock implements SmsGateway {}

class _MemorySecure extends SecureStore {
  _MemorySecure() : super(const FlutterSecureStorage());

  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();
}

void main() {
  late LocalDeviceRepository repository;
  late _MockGateway gateway;
  late DateTime now;
  late SendDeviceCommand send;
  final device = Device(id: 'd1', name: 'منزل', simNumber: '09120000000', createdAt: DateTime(2026));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = LocalDeviceRepository(
      store: KeyValueStore(await SharedPreferences.getInstance()),
      secure: _MemorySecure(),
    );
    await repository.saveDevice(device, password: '1234');
    gateway = _MockGateway();
    now = DateTime(2026, 11, 20, 10);
    send = SendDeviceCommand(repository: repository, gateway: gateway, clock: () => now);
    when(
      () => gateway.send(
        number: any(named: 'number'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => SmsSendResult.sent);
  });

  test('sends, logs a masked message and stores the config patch', () async {
    final outcome = await send(device, const Gsa212Commands('1234').sirenTime(60));

    expect(outcome.status, SendStatus.sent);
    verify(() => gateway.send(number: '09120000000', body: 'J1234060')).called(1);
    final messages = await repository.getMessages('d1');
    expect(messages.single.direction, MessageDirection.outgoing);
    expect(messages.single.body, 'J••••060');
    expect((await repository.getConfig('d1'))[ConfigKeys.sirenTime], 60);
  });

  test('enforces the two-minute gap between SMS', () async {
    await send(device, const Gsa212Commands('1234').arm());
    now = now.add(const Duration(seconds: 50));

    final blocked = await send(device, const Gsa212Commands('1234').disarm());
    expect(blocked.status, SendStatus.cooldown);
    expect(blocked.wait, const Duration(seconds: 70));

    now = now.add(const Duration(seconds: 70));
    expect((await send(device, const Gsa212Commands('1234').disarm())).status, SendStatus.sent);
    verify(
      () => gateway.send(
        number: any(named: 'number'),
        body: any(named: 'body'),
      ),
    ).called(2);
  });

  test('failed send does not start the cooldown', () async {
    when(
      () => gateway.send(
        number: any(named: 'number'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => SmsSendResult.failed);
    expect((await send(device, const Gsa212Commands('1234').arm())).status, SendStatus.failed);
    expect(await send.remainingCooldown('d1'), Duration.zero);
    expect(await repository.getMessages('d1'), isEmpty);
  });

  test('processing a reply updates status and history', () async {
    final process = ProcessDeviceReply(repository: repository);
    await process('d1', 'دستگاه فعال شد.', at: now);

    final status = await repository.getStatus('d1');
    expect(status.arm.name, 'armed');
    expect(status.updatedAt, now);
    expect((await repository.getMessages('d1')).single.isIncoming, isTrue);
  });

  test('finds a device by sender regardless of +98 formatting', () async {
    expect((await repository.findBySender('+989120000000'))?.id, 'd1');
    expect(await repository.findBySender('+989129999999'), isNull);
  });
}
