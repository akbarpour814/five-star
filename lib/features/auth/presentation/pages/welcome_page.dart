import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../devices/presentation/pages/register_device_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    const AppLogo(size: 150),
                    const SizedBox(height: 28),
                    const Text(
                      'دزدگیر سیم‌کارتی Five Star',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'کنترل و مدیریت کامل دستگاه GSA-212 از راه دور',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                    ),
                    const SizedBox(height: 36),
                    const _Feature(icon: Icons.shield_outlined, text: 'فعال، غیرفعال و نیمه‌فعال کردن دزدگیر'),
                    const _Feature(icon: Icons.toggle_on_outlined, text: 'کنترل چهار خروجی و درب‌بازکن'),
                    const _Feature(icon: Icons.tune, text: 'تنظیمات کامل زون‌ها، آژیر و پارتیشن‌بندی'),
                    const _Feature(icon: Icons.lock_outline, text: 'ورود امن با رمز و اثر انگشت'),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                        ),
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const RegisterDevicePage(withAppSecurity: true))),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('ثبت اولین دستگاه'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
