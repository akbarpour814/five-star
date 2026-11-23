import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../cubit/app_cooldown_cubit.dart';

/// Floating, draggable ring that fills up during the two-minute SMS gap and fades out when it ends.
/// Place it in a full-screen [Stack] above the app's navigator.
class CooldownBubble extends StatefulWidget {
  const CooldownBubble({super.key, required this.enabled});

  /// False while the app is locked or not registered yet.
  final bool enabled;

  @override
  State<CooldownBubble> createState() => _CooldownBubbleState();
}

class _CooldownBubbleState extends State<CooldownBubble> {
  static const _size = 68.0;
  static const _labelHeight = 22.0;
  static const _margin = 12.0;

  Offset? _position;
  bool _dragging = false;
  AppCooldownState _shown = const AppCooldownState();

  double _height(AppCooldownState state) => _size + (state.showName ? _labelHeight : 0);

  Offset _clamp(Offset value, Size area, EdgeInsets padding, double height) => Offset(
    value.dx.clamp(_margin, area.width - _size - _margin),
    value.dy.clamp(padding.top + _margin, area.height - padding.bottom - height - _margin),
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCooldownCubit, AppCooldownState>(
      builder: (context, state) {
        final visible = widget.enabled && state.active;
        if (state.active) _shown = state;
        return LayoutBuilder(
          builder: (context, constraints) {
            final area = constraints.biggest;
            final padding = MediaQuery.paddingOf(context);
            final height = _height(_shown);
            final position = _clamp(
              _position ?? Offset(area.width - _size - _margin, area.height * 0.62),
              area,
              padding,
              height,
            );
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: _dragging ? Duration.zero : const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: position.dx,
                  top: position.dy,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      opacity: visible ? 1 : 0,
                      child: GestureDetector(
                        onPanStart: (_) => setState(() {
                          _dragging = true;
                          _position = position;
                        }),
                        onPanUpdate: (details) => setState(() {
                          _position = _clamp(_position! + details.delta, area, padding, height);
                        }),
                        onPanEnd: (_) => setState(() {
                          _dragging = false;
                          final snapLeft = _position!.dx + _size / 2 < area.width / 2;
                          _position = Offset(snapLeft ? _margin : area.width - _size - _margin, _position!.dy);
                        }),
                        child: _Bubble(state: _shown, lifted: _dragging),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.state, required this.lifted});

  final AppCooldownState state;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final total = sl<AppPreferences>().smsInterval.inMilliseconds;
    final progress = (1 - state.remaining.inMilliseconds / total).clamp(0.0, 1.0);
    // Sits above the navigator, so it needs its own Material for text styling.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: lifted ? 1.08 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _CooldownBubbleState._size,
              height: _CooldownBubbleState._size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: lifted ? 0.35 : 0.22),
                    blurRadius: lifted ? 20 : 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.ice,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sms_outlined, size: 14, color: AppColors.textSecondary),
                        Text(
                          AppDateFormat.countdown(state.remaining),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (state.showName && state.deviceName != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxWidth: 90),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  state.deviceName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
