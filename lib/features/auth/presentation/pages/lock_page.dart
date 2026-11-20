import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/pin_pad.dart';
import '../bloc/auth_bloc.dart';

class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthBloc>().add(const AuthBiometricRequested());
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _reset() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'بازگشت به تنظیمات اولیه',
      message:
          'تمام دستگاه‌ها، تاریخچه پیام‌ها و رمز ورود برنامه حذف می‌شود و باید دوباره دستگاه را ثبت کنید. '
          'تنظیمات خود دستگاه دزدگیر تغییری نمی‌کند.\n\nآیا ادامه می‌دهید؟',
      confirmLabel: 'حذف و شروع مجدد',
      destructive: true,
    );
    if (confirmed && mounted) context.read<AuthBloc>().add(const AuthResetRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final lockedFor = state.lockedUntil?.difference(DateTime.now());
              final locked = lockedFor != null && !lockedFor.isNegative;
              final remainingAttempts = AuthBloc.maxAttempts - state.failedAttempts;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      const AppLogo(size: 104),
                      const SizedBox(height: 20),
                      const Text(
                        'رمز ورود را وارد کنید',
                        style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 22,
                        child: Text(
                          locked
                              ? 'ورود موقتا قفل است؛ ${TextNormalizer.toPersianDigits(lockedFor.inSeconds + 1)} ثانیه صبر کنید'
                              : state.failedAttempts > 0
                              ? 'رمز اشتباه است • ${TextNormalizer.toPersianDigits(remainingAttempts)} تلاش باقی مانده'
                              : state.canUseBiometric
                              ? 'یا از اثر انگشت استفاده کنید'
                              : '',
                          style: TextStyle(
                            color: state.failedAttempts > 0 || locked ? const Color(0xFFFFCDD2) : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      PinPad(
                        errorTick: state.errorTick,
                        enabled: !locked && !state.busy,
                        onCompleted: (pin) => context.read<AuthBloc>().add(AuthPinSubmitted(pin)),
                        onBiometric: state.canUseBiometric
                            ? () => context.read<AuthBloc>().add(const AuthBiometricRequested())
                            : null,
                      ),
                      const SizedBox(height: 28),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: state.busy ? null : _reset,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('بازگشت به تنظیمات اولیه'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
