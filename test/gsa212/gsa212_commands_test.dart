import 'package:five_star/features/gsa212/domain/device_command.dart';
import 'package:five_star/features/gsa212/domain/gsa212_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const c = Gsa212Commands('0000');

  group('examples from the 212 manual', () {
    final cases = <String, DeviceCommand>{
      '10000': c.outputToggle(1),
      '40000': c.outputToggle(4),
      '1L0000': c.outputMomentary(1),
      '4L0000': c.outputMomentary(4),
      '50000': c.arm(),
      '60000': c.disarm(),
      '70000': c.partSet(),
      '80000': c.silentArm(),
      '*0000': c.simBalance(),
      'B0000': c.status(),
      'C0000': c.memories(),
      'D0000': c.openDoor(),
      'E00000109121234567': c.saveNumber(memory: 1, phone: '09121234567'),
      'F0000': c.stopDialing(),
      'G0000*141': c.ussd('*141'),
      'H10000': c.remoteReport(true),
      'H00000': c.remoteReport(false),
      'I10000': c.powerReport(true),
      'I00000': c.powerReport(false),
      'J0000090': c.sirenTime(90),
      'J0000150': c.sirenTime(150),
      'K00000': c.securityLevel(high: false),
      'K10000': c.securityLevel(high: true),
      'L0000002': c.deleteRemote(2),
      'M00000': c.soundMode(SoundMode.speakerAndPiezo),
      'M10000': c.soundMode(SoundMode.piezoOnly),
      'M20000': c.soundMode(SoundMode.silent),
      'N0000': c.antenna(),
      'O10000': c.speakerCutReport(true),
      'O00000': c.speakerCutReport(false),
      'P0000100': c.autoBalance(100),
      'Q0000030': c.serviceReminder(30),
      'T10000': c.fuseReport(true),
      'T00000': c.fuseReport(false),
      'Z30000112255': c.zoneSettings(
        zone: 3,
        normallyClosed: true,
        dingDong: true,
        type: ZoneType.delayed,
        delaySeconds: 255,
      ),
      '@10000': c.sensorBatteryReport(true),
      '@00000': c.sensorBatteryReport(false),
      '!00000': c.dialMode(pulse: false),
      '!10000': c.dialMode(pulse: true),
      '?40000': c.ringCount(4),
      '%10000': c.landlineControl(true),
      '%00000': c.landlineControl(false),
      'U0200000101': c.remotePartition(remote: 2, zones: ZoneMask.parse('0101')),
      'Y0100001101': c.memoryPartition(memory: 1, zones: ZoneMask.parse('1101')),
      'S0200000001': c.passwordPartition(part: 2, zones: ZoneMask.parse('0001')),
      'W10000': c.partitionMode(true),
      'X200001111': c.partPasswordChange(part: 2, oldPassword: '0000', newPassword: '1111'),
      'V2A1111': c.partControl(part: 2, arm: true, partPassword: '1111'),
      'R0300000101030': c.outputProgram(output: 3, zones: ZoneMask.parse('0101'), seconds: 30),
      '+20000010': c.notificationPartition(zone: 2, siren: false, sms: true, call: false),
    };

    cases.forEach((expected, command) {
      test('${command.title} → $expected', () => expect(command.body, expected));
    });
  });

  test('password change uses old then new password', () {
    expect(c.changePassword('1234').body, '000001234');
  });

  test('sim charge appends the charge code after the password', () {
    expect(c.simCharge('123456789').body, '#0000123456789');
  });

  test('non-delayed zones always send 000 as delay', () {
    final cmd = c.zoneSettings(
      zone: 1,
      normallyClosed: false,
      dingDong: false,
      type: ZoneType.normal,
      delaySeconds: 40,
    );
    expect(cmd.body, 'Z10000000000');
  });

  test('masked body hides every password', () {
    const custom = Gsa212Commands('4321');
    expect(custom.arm().maskedBody, '5••••');
    expect(custom.changePassword('9999').maskedBody, '0••••••••');
    expect(custom.partControl(part: 1, arm: false, partPassword: '5555').maskedBody, 'V1D••••');
    expect(custom.saveNumber(memory: 12, phone: '02112345678').maskedBody, 'E••••1202112345678');
  });

  test('out-of-range values are rejected', () {
    expect(() => c.sirenTime(256), throwsArgumentError);
    expect(() => c.deleteRemote(31), throwsArgumentError);
    expect(() => c.ringCount(0), throwsArgumentError);
    expect(() => c.outputToggle(5), throwsArgumentError);
    expect(() => c.changePassword('12a4'), throwsArgumentError);
  });

  test('config patch records the setting a command applies', () {
    expect(c.sirenTime(120).configPatch, {ConfigKeys.sirenTime: 120});
    expect(c.securityLevel(high: true).configPatch, {ConfigKeys.securityHigh: true});
  });
}
