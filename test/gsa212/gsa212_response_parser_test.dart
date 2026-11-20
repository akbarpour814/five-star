import 'package:five_star/features/devices/domain/entities/device_message.dart';
import 'package:five_star/features/devices/domain/entities/device_status.dart';
import 'package:five_star/features/gsa212/domain/gsa212_commands.dart';
import 'package:five_star/features/gsa212/domain/gsa212_response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = Gsa212ResponseParser();

  DeviceStatus apply(String text, [DeviceStatus base = DeviceStatus.empty]) => parser.parse(text).patch!(base);

  group('arm state replies', () {
    test('armed', () => expect(apply('دستگاه فعال شد.').arm, ArmState.armed));
    test('disarmed', () => expect(apply('دستگاه غیر فعال شد.').arm, ArmState.disarmed));
    test('partset', () => expect(apply('دستگاه نیمه فعال شد.').arm, ArmState.partset));
    test('silent with Arabic yeh', () => expect(apply('دستگاه بي صدا فعال شد.').arm, ArmState.silent));
  });

  group('outputs', () {
    test('Arabic digit and yeh variant', () {
      final status = apply('خروجي ١ فعال شد');
      expect(status.outputs, [true, null, null, null]);
    });

    test('turned off', () {
      final status = apply('خروجي 3 غیرفعال شد', DeviceStatus.empty.withOutput(3, true));
      expect(status.outputs[2], false);
    });
  });

  test('status inquiry reply fills the snapshot', () {
    const reply = 'وضعیت دستگاه:\nسیستم نیمه فعال\nخروجی ها:\n١ روشن\n۲ خاموش\n۳ روشن\n۴ خاموش\nبرق قطع\nباطری ضعیف';
    final parsed = parser.parse(reply);
    final status = parsed.patch!(DeviceStatus.empty);
    expect(status.arm, ArmState.partset);
    expect(status.outputs, [true, false, true, false]);
    expect(status.powerConnected, false);
    expect(status.batteryOk, false);
    expect(parsed.severity, MessageSeverity.alert);
  });

  test('memory inquiry reply', () {
    final status = apply('M1:09121234567,M2:,M11:02112345678,M30:,');
    expect(status.memories[1], '09121234567');
    expect(status.memories[2], '');
    expect(status.memories[11], '02112345678');
    expect(status.memories[30], '');
  });

  test('antenna reply and level', () {
    final parsed = parser.parse('قدرت آنتن دهی 22 می باشد.(خوب)');
    expect(parsed.patch!(DeviceStatus.empty).antenna, 22);
    expect(parsed.patch!(DeviceStatus.empty).signal, SignalLevel.good);
    expect(SignalLevel.fromValue(16), SignalLevel.medium);
    expect(SignalLevel.fromValue(12), SignalLevel.weak);
  });

  group('settings confirmations update config', () {
    final cases = <String, Map<String, Object?>>{
      'زمان آژیر:150 ثانیه': {ConfigKeys.sirenTime: 150},
      'سطح امنیت بالا فعال شد': {ConfigKeys.securityHigh: true},
      'سطح امنیت بالا غیر فعال شد': {ConfigKeys.securityHigh: false},
      'گزارش ریموت فعال شد': {ConfigKeys.remoteReport: true},
      'گزارش برق غیر فعال شد': {ConfigKeys.powerReport: false},
      'خروجی بلندگووسیرن فعال شد': {ConfigKeys.soundMode: 0},
      'خروجی بلندگو غیرفعال شد': {ConfigKeys.soundMode: 1},
      'خروجی بلندگووسیرن غیر فعال شد': {ConfigKeys.soundMode: 2},
      'اعلام قطع اسپیکر فعال شد': {ConfigKeys.speakerReport: true},
      'اعلام قطع فیوز غیر فعال شد': {ConfigKeys.fuseReport: false},
      'قابلیت پارتیشن بندی فعال شد': {ConfigKeys.partitionMode: true},
      'گزارش باتری سنسور فعال شد': {ConfigKeys.sensorBattery: true},
      'شماره گیری پالس تایید شد': {ConfigKeys.dialPulse: true},
      'تعداد زنگ4 تایید شد': {ConfigKeys.ringCount: 4},
      'کنترل با تماس غیرفعال شد': {ConfigKeys.landlineControl: false},
    };
    cases.forEach((text, config) {
      test(text, () {
        final parsed = parser.parse(text);
        expect(parsed.recognized, isTrue);
        expect(parsed.config, config);
      });
    });
  });

  group('other confirmations are recognized', () {
    for (final text in [
      'درب بازشد.',
      'توقف شماره گيري و آرم مجدد',
      'ریموت شماره002 حذف شد',
      'خروجی3=زون1(100ثانیه)',
      'دسترسی رمز شماره 01 به زون های1و2 تایید شد',
      'دسترسی ریموت شماره 01 به زون های1و2 تایید شد',
      'دسترسی حافظه شماره 01 به زون های1و2 تایید شد',
      'قسمت 2 فعال شد.',
      'OK>>New Password:1111',
    ]) {
      test(text, () => expect(parser.parse(text).recognized, isTrue));
    }
  });

  test('unsolicited power-cut alert', () {
    final parsed = parser.parse('هشدار: قطع برق');
    expect(parsed.severity, MessageSeverity.alert);
    expect(parsed.patch!(DeviceStatus.empty).powerConnected, false);
  });

  test('unknown text is kept as unrecognized', () {
    final parsed = parser.parse('سلام');
    expect(parsed.recognized, isFalse);
    expect(parsed.patch, isNull);
  });
}
