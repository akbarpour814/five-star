import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/platform/sms_gateway.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/pin_pad.dart';
import '../../domain/auth_repository.dart';
import '../bloc/auth_bloc.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  Future<void> _reset(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'بازگشت به تنظیمات اولیه',
      message: 'تمام دستگاه‌ها، تاریخچه و رمز ورود حذف می‌شود و برنامه از ابتدا شروع می‌شود. ادامه می‌دهید؟',
      confirmLabel: 'حذف همه',
      destructive: true,
    );
    if (ok && context.mounted) context.read<AuthBloc>().add(const AuthResetRequested());
  }

  @override
  Widget build(BuildContext context) {
    final gateway = sl<SmsGateway>();
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    const Expanded(
                      child: Text(
                        'تنظیمات برنامه',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: 'امنیت',
                    icon: Icons.lock_outline,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.pin_outlined, color: AppColors.primary),
                          title: const Text('تغییر رمز ورود'),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ChangePinPage())),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.fingerprint, color: AppColors.primary),
                          title: const Text('ورود با اثر انگشت'),
                          subtitle: Text(
                            state.biometricAvailable ? 'در کنار رمز ۴ رقمی' : 'روی این دستگاه در دسترس نیست',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: state.biometricEnabled && state.biometricAvailable,
                          onChanged: state.biometricAvailable
                              ? (v) => context.read<AuthBloc>().add(AuthBiometricToggled(v))
                              : null,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock_clock_outlined, color: AppColors.primary),
                          title: const Text('قفل کردن برنامه'),
                          onTap: () => context.read<AuthBloc>().add(const AuthLockRequested()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'ارسال و دریافت پیامک',
                    icon: Icons.sms_outlined,
                    child: Text(
                      gateway.sendsDirectly
                          ? 'دستورات مستقیما از سیم‌کارت گوشی ارسال و پاسخ‌های دستگاه به‌صورت خودکار دریافت و پردازش می‌شوند.'
                          : 'دستورات در برنامه پیام‌رسان آماده می‌شوند. پاسخ دستگاه را کپی کرده و در بخش «ثبت پاسخ دستگاه» قرار دهید.',
                      style: const TextStyle(fontSize: 13, height: 1.8, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'بازنشانی',
                    icon: Icons.restart_alt,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () => _reset(context),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('بازگشت به تنظیمات اولیه'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'FiveStar • نسخه ۱.۰.۰',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePinPage extends StatefulWidget {
  const _ChangePinPage();

  @override
  State<_ChangePinPage> createState() => _ChangePinPageState();
}

enum _PinStage { current, next, confirm }

class _ChangePinPageState extends State<_ChangePinPage> {
  final AuthRepository _auth = sl();
  _PinStage _stage = _PinStage.current;
  String _next = '';
  int _errorTick = 0;
  String? _error;

  Future<void> _onCompleted(String pin) async {
    switch (_stage) {
      case _PinStage.current:
        if (await _auth.verifyPin(pin)) {
          setState(() {
            _stage = _PinStage.next;
            _error = null;
          });
        } else {
          setState(() {
            _errorTick++;
            _error = 'رمز فعلی اشتباه است';
          });
        }
      case _PinStage.next:
        setState(() {
          _next = pin;
          _stage = _PinStage.confirm;
          _error = null;
        });
      case _PinStage.confirm:
        if (pin == _next) {
          await _auth.setPin(pin);
          if (!mounted) return;
          showAppSnack(context, 'رمز ورود تغییر کرد');
          Navigator.of(context).pop();
        } else {
          setState(() {
            _stage = _PinStage.next;
            _errorTick++;
            _error = 'رمزها یکسان نبودند';
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_stage) {
      _PinStage.current => 'رمز فعلی را وارد کنید',
      _PinStage.next => 'رمز جدید ۴ رقمی را وارد کنید',
      _PinStage.confirm => 'رمز جدید را تکرار کنید',
    };
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: BackButton(color: Colors.white),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 20,
                          child: Text(_error ?? '', style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 13)),
                        ),
                        const SizedBox(height: 28),
                        PinPad(key: ValueKey(_stage), errorTick: _errorTick, onCompleted: _onCompleted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
