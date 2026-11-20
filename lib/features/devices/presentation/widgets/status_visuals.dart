import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/device_status.dart';

extension ArmStateVisuals on ArmState {
  Color get color => switch (this) {
    ArmState.armed => AppColors.danger,
    ArmState.silent => const Color(0xFF8E24AA),
    ArmState.partset => AppColors.warning,
    ArmState.disarmed => AppColors.success,
    ArmState.unknown => AppColors.textSecondary,
  };

  IconData get icon => switch (this) {
    ArmState.armed => Icons.lock_rounded,
    ArmState.silent => Icons.notifications_off_rounded,
    ArmState.partset => Icons.shield_moon_outlined,
    ArmState.disarmed => Icons.lock_open_rounded,
    ArmState.unknown => Icons.help_outline_rounded,
  };
}

class ArmStateChip extends StatelessWidget {
  const ArmStateChip(this.state, {super.key, this.onDark = false});

  final ArmState state;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : state.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.18) : state.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(state.icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            state == ArmState.unknown ? 'وضعیت نامشخص' : 'دزدگیر ${state.label}',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.level, this.color = Colors.white});

  final SignalLevel? level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = switch (level) {
      SignalLevel.good => 3,
      SignalLevel.medium => 2,
      SignalLevel.weak => 1,
      null => 0,
    };
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 4,
              height: 6.0 + i * 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: i < filled ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
