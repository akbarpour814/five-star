import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/text_normalizer.dart';

/// Four-dot PIN entry with an on-screen keypad; calls [onCompleted] once all digits are typed.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.length = 4,
    this.errorTick = 0,
    this.enabled = true,
    this.onBiometric,
    this.biometricIcon = Icons.fingerprint,
    this.light = true,
  });

  final ValueChanged<String> onCompleted;
  final int length;

  /// Change this value to shake the dots and clear the entry.
  final int errorTick;
  final bool enabled;
  final VoidCallback? onBiometric;
  final IconData biometricIcon;

  /// Light-on-dark styling for gradient backgrounds.
  final bool light;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _value = '';
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  final _focus = FocusNode();

  @override
  void didUpdateWidget(covariant PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorTick != oldWidget.errorTick) {
      setState(() => _value = '');
      _shake.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(String digit) {
    if (!widget.enabled || _value.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _value += digit);
    if (_value.length == widget.length) {
      final pin = _value;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _value = '');
        widget.onCompleted(pin);
      });
    }
  }

  void _remove() {
    if (_value.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _remove();
      return KeyEventResult.handled;
    }
    final char = event.character;
    if (char != null) {
      final digit = TextNormalizer.digitsToLatin(char);
      if (RegExp(r'^\d$').hasMatch(digit)) {
        _add(digit);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.light ? Colors.white : Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(sin(_shake.value * pi * 6) * 12 * (1 - _shake.value), 0),
              child: child,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _value.length ? fg : Colors.transparent,
                        border: Border.all(color: fg.withValues(alpha: 0.8), width: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Directionality(
            textDirection: TextDirection.ltr,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 22,
                childAspectRatio: 1.15,
                children: [
                  for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                    _Key(label: TextNormalizer.toPersianDigits(d), light: widget.light, onTap: () => _add(d)),
                  if (widget.onBiometric != null)
                    _Key(icon: widget.biometricIcon, light: widget.light, onTap: widget.onBiometric!, flat: true)
                  else
                    const SizedBox.shrink(),
                  _Key(label: '۰', light: widget.light, onTap: () => _add('0')),
                  _Key(icon: Icons.backspace_outlined, light: widget.light, onTap: _remove, flat: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap, required this.light, this.flat = false});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool light;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final fg = light ? Colors.white : primary;
    final bg = flat
        ? Colors.transparent
        : light
        ? Colors.white.withValues(alpha: 0.14)
        : primary.withValues(alpha: 0.07);
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: icon != null
              ? Icon(icon, color: fg, size: 30)
              : Text(
                  label!,
                  style: TextStyle(color: fg, fontSize: 28, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
