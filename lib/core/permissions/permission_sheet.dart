import 'package:flutter/material.dart';

import '../di/injection.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'permission_service.dart';

class _Rationale {
  const _Rationale({required this.icon, required this.title, required this.intro, required this.points});

  final IconData icon;
  final String title;
  final String intro;
  final List<String> points;
}

const _rationales = {
  AppPermission.sms: _Rationale(
    icon: Icons.sms_outlined,
    title: 'دسترسی به پیامک',
    intro: 'Five Star دزدگیر را با پیامک کنترل می‌کند؛ برای همین به دسترسی پیامک گوشی شما نیاز دارد.',
    points: [
      'ارسال دستورات از سیم‌کارت گوشی به سیم‌کارت دستگاه',
      'دریافت و نمایش خودکار پاسخ‌ها و هشدارهای دستگاه',
      'خواندن گزارش‌هایی که وقتی برنامه بسته بوده رسیده‌اند، برای به‌روز شدن وضعیت دستگاه',
      'فقط پیامک‌های شماره دستگاه‌های ثبت‌شده خوانده می‌شوند و پیامک‌های دیگر شما دیده نمی‌شوند',
    ],
  ),
  AppPermission.phone: _Rationale(
    icon: Icons.sim_card_outlined,
    title: 'دسترسی به اطلاعات سیم‌کارت',
    intro: 'برای گوشی‌های دو سیم‌کارته، برنامه باید سیم‌کارت‌های گوشی شما را بشناسد.',
    points: [
      'نمایش اپراتور و شماره هر سیم‌کارت برای انتخاب راحت‌تر',
      'ارسال دستور از همان سیم‌کارتی که برای هر دستگاه انتخاب کرده‌اید',
      'برنامه هیچ تماسی برقرار نمی‌کند',
    ],
  ),
  AppPermission.biometric: _Rationale(
    icon: Icons.fingerprint,
    title: 'ورود با اثر انگشت',
    intro: 'می‌توانید به‌جای وارد کردن رمز ۴ رقمی، با اثر انگشت یا تشخیص چهره گوشی وارد برنامه شوید.',
    points: [
      'ورود سریع و امن به برنامه',
      'اطلاعات اثر انگشت فقط در گوشی شما می‌ماند و برنامه به آن دسترسی ندارد',
      'ورود با رمز ۴ رقمی همیشه در دسترس است',
    ],
  ),
};

/// Explains [permission] in a bottom sheet and only then shows the OS prompt.
/// Returns false when the user declines; callers must stop the action that needed it.
Future<bool> ensureAppPermission(BuildContext context, AppPermission permission) async {
  final service = sl<PermissionService>();
  var status = await service.status(permission);
  // Biometric has no queryable status, so its explanation is always shown before enabling it.
  if (permission != AppPermission.biometric &&
      (!service.hasSystemPrompt(permission) || status == AppPermissionStatus.granted)) {
    return true;
  }
  if (!context.mounted) return false;

  final accepted = await _showSheet(context, permission, settings: status == AppPermissionStatus.permanentlyDenied);
  if (!context.mounted) return false;
  if (accepted != true) {
    showAppSnack(context, 'بدون این دسترسی، ادامه این کار امکان‌پذیر نیست', error: true);
    return false;
  }
  if (!service.hasSystemPrompt(permission)) return true;
  if (status == AppPermissionStatus.permanentlyDenied) {
    await service.openSettings();
    return false;
  }

  status = await service.request(permission);
  if (status == AppPermissionStatus.granted) return true;
  if (!context.mounted) return false;
  if (status == AppPermissionStatus.permanentlyDenied) {
    final openSettings = await _showSheet(context, permission, settings: true);
    if (openSettings == true) await service.openSettings();
  } else {
    showAppSnack(context, 'بدون این دسترسی، ادامه این کار امکان‌پذیر نیست', error: true);
  }
  return false;
}

Future<bool?> _showSheet(BuildContext context, AppPermission permission, {required bool settings}) {
  final rationale = _rationales[permission]!;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
                child: Icon(rationale.icon, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              rationale.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              rationale.intro,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.8),
            ),
            const SizedBox(height: 16),
            for (final point in rationale.points)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(point, style: const TextStyle(fontSize: 13.5, height: 1.7))),
                  ],
                ),
              ),
            if (settings) ...[
              const SizedBox(height: 8),
              const InfoBanner(
                icon: Icons.settings_outlined,
                color: Color(0xFFB7791F),
                text: 'این دسترسی قبلا رد شده است. در تنظیمات گوشی، بخش مجوزهای Five Star، آن را فعال کنید.',
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(
              label: settings ? 'رفتن به تنظیمات' : 'متوجه شدم، ادامه',
              icon: settings ? Icons.settings_outlined : Icons.check_rounded,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('فعلا نه')),
          ],
        ),
      ),
    ),
  );
}
