import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/permissions/permission_sheet.dart';
import '../../../../core/platform/sms_gateway.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/common.dart';
import '../../../gsa212/domain/device_command.dart';
import '../../domain/usecases/send_device_command.dart';
import '../cubit/device_cubit.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

abstract final class SendFeedback {
  static void showRoot(String message, {bool error = false}) {
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : AppColors.primaryDark),
      );
  }

  static String message(SendOutcome outcome) => switch (outcome.status) {
    SendStatus.sent => 'پیامک ارسال شد؛ منتظر پاسخ دستگاه باشید',
    SendStatus.openedComposer => 'پیام‌رسان باز شد؛ پیامک را ارسال و پاسخ دستگاه را در برنامه ثبت کنید',
    SendStatus.cooldown => 'تا ارسال بعدی ${AppDateFormat.countdown(outcome.wait)} صبر کنید',
    SendStatus.permissionDenied => 'اجازه ارسال پیامک یا دسترسی به سیم‌کارت داده نشد',
    SendStatus.simUnavailable =>
      'سیم‌کارت انتخاب‌شده برای این دستگاه در گوشی فعال نیست؛ آن را در تنظیمات دستگاه تغییر دهید',
    SendStatus.failed => 'ارسال پیامک ناموفق بود',
  };
}

/// On Android, explains and requests SMS (and SIM, when a slot is chosen) permissions before sending.
/// Returns false when the user declines, so the send must not happen.
Future<bool> ensureSendPermissions(BuildContext context, {int? simSlot}) async {
  if (!sl<SmsGateway>().sendsDirectly) return true;
  if (!await ensureAppPermission(context, AppPermission.sms) || !context.mounted) return false;
  if (simSlot != null && !await ensureAppPermission(context, AppPermission.phone)) return false;
  return context.mounted;
}

/// Shows the command preview and, on confirmation, sends it through [cubit].
Future<SendOutcome?> sendDeviceCommand(
  BuildContext context,
  DeviceCubit cubit,
  DeviceCommand command, {
  Future<SendOutcome> Function()? sender,
}) async {
  final state = cubit.state;
  if (state.cooldown > Duration.zero) {
    showAppSnack(context, SendFeedback.message(SendOutcome(SendStatus.cooldown, wait: state.cooldown)), error: true);
    return null;
  }
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CommandSheet(command: command, deviceName: state.device.name, sim: state.device.simNumber),
  );
  if (confirmed != true || !context.mounted) return null;
  if (!await ensureSendPermissions(context, simSlot: state.device.simSlot)) return null;

  final outcome = await (sender?.call() ?? cubit.send(command));
  if (context.mounted) showAppSnack(context, SendFeedback.message(outcome), error: !outcome.delivered);
  return outcome;
}

class _CommandSheet extends StatefulWidget {
  const _CommandSheet({required this.command, required this.deviceName, required this.sim});

  final DeviceCommand command;
  final String deviceName;
  final String sim;

  @override
  State<_CommandSheet> createState() => _CommandSheetState();
}

class _CommandSheetState extends State<_CommandSheet> {
  bool _reveal = false;

  @override
  Widget build(BuildContext context) {
    final code = _reveal ? widget.command.body : widget.command.maskedBody;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconBadge(icon: Icons.send_rounded, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.command.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'ارسال به ${widget.deviceName}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.ice, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Text('متن پیامک', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(
                    code,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  IconButton(
                    tooltip: _reveal ? 'پنهان کردن رمز' : 'نمایش رمز',
                    icon: Icon(_reveal ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _reveal = !_reveal),
                  ),
                  IconButton(
                    tooltip: 'کپی',
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.command.body));
                      showAppSnack(context, 'متن دستور کپی شد');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.sim_card_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(widget.sim, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13)),
                const Spacer(),
                const Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'ارسال بعدی پس از ${AppDateFormat.duration(sl<AppPreferences>().smsInterval)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'ارسال دستور',
              icon: Icons.send_rounded,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          ],
        ),
      ),
    );
  }
}
