import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-screen brand gradient with soft light rings, echoing the FiveStar badge.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(
        children: [
          const Positioned(top: -120, left: -80, child: _Ring(size: 320)),
          const Positioned(bottom: -140, right: -100, child: _Ring(size: 380)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 28),
        ),
      ),
    );
  }
}

/// Curved gradient header used at the top of inner pages.
class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, required this.child, this.bottomRadius = 32});

  final Widget child;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}
