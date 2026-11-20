import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../../gsa212/domain/gsa212_commands.dart';
import '../cubit/device_cubit.dart';

/// Countdown shown while the two-minute gap between SMS to the device is running.
class CooldownBanner extends StatelessWidget {
  const CooldownBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DeviceCubit, DeviceState, Duration>(
      selector: (s) => s.cooldown,
      builder: (context, left) {
        final visible = left > Duration.zero;
        final progress = 1 - left.inMilliseconds / Gsa212Commands.minInterval.inMilliseconds;
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: !visible
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB7791F), size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'فاصله دو دقیقه‌ای بین پیامک‌ها',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8A5A00)),
                            ),
                          ),
                          Text(
                            AppDateFormat.countdown(left),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF8A5A00)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0, 1),
                          minHeight: 5,
                          backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation(AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
