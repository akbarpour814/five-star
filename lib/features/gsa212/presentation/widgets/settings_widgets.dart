import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../devices/domain/usecases/send_device_command.dart';
import '../../../devices/presentation/cubit/device_cubit.dart';
import '../../../devices/presentation/widgets/cooldown_banner.dart';
import '../../../devices/presentation/widgets/send_feedback.dart';
import '../../domain/device_command.dart';

/// Inner settings page shell: gradient header, cooldown banner and a scrolling body.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({super.key, required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          BlocSelector<DeviceCubit, DeviceState, String>(
                            selector: (s) => s.device.name,
                            builder: (context, name) => Text(
                              subtitle ?? name,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          const CooldownBanner(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) => children[i],
            ),
          ),
        ],
      ),
    );
  }
}

Future<SendOutcome?> sendFromSettings(BuildContext context, DeviceCommand command) =>
    sendDeviceCommand(context, context.read<DeviceCubit>(), command);

/// On/off setting with two buttons; highlights the last value sent or confirmed.
class ToggleSettingCard extends StatelessWidget {
  const ToggleSettingCard({
    super.key,
    required this.title,
    required this.icon,
    required this.configKey,
    required this.command,
    this.description,
    this.onLabel = 'فعال',
    this.offLabel = 'غیرفعال',
  });

  final String title;
  final String? description;
  final IconData icon;
  final String configKey;
  final DeviceCommand Function(DeviceState state, bool value) command;
  final String onLabel;
  final String offLabel;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceCubit, DeviceState>(
      builder: (context, state) {
        final current = state.configValue<bool>(configKey);
        return SectionCard(
          title: title,
          icon: icon,
          trailing: current == null ? null : _StateTag(on: current, onLabel: onLabel, offLabel: offLabel),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (description != null) ...[
                Text(description!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7)),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _ChoiceButton(
                      label: onLabel,
                      selected: current == true,
                      onTap: () => sendFromSettings(context, command(state, true)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceButton(
                      label: offLabel,
                      selected: current == false,
                      onTap: () => sendFromSettings(context, command(state, false)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StateTag extends StatelessWidget {
  const _StateTag({required this.on, required this.onLabel, required this.offLabel});

  final bool on;
  final String onLabel;
  final String offLabel;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(
        on ? onLabel : offLabel,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: selected ? AppColors.buttonGradient : null,
        color: selected ? null : AppColors.ice,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Center(
              child: Text(
                label,
                style: TextStyle(color: selected ? Colors.white : AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single numeric value with range validation and a send button.
class NumberSettingCard extends StatefulWidget {
  const NumberSettingCard({
    super.key,
    required this.title,
    required this.icon,
    required this.min,
    required this.max,
    required this.label,
    required this.command,
    this.configKey,
    this.description,
    this.unit,
    this.initial,
  });

  final String title;
  final IconData icon;
  final int min;
  final int max;
  final String label;
  final String? unit;
  final String? description;
  final String? configKey;
  final int? initial;
  final DeviceCommand Function(DeviceState state, int value) command;

  @override
  State<NumberSettingCard> createState() => _NumberSettingCardState();
}

class _NumberSettingCardState extends State<NumberSettingCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = context.read<DeviceCubit>().state;
    final saved = widget.configKey == null ? null : state.configValue<int>(widget.configKey!);
    _controller = TextEditingController(text: (saved ?? widget.initial)?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (!_formKey.currentState!.validate()) return;
    final value = int.parse(_controller.text);
    sendFromSettings(context, widget.command(context.read<DeviceCubit>().state, value));
  }

  @override
  Widget build(BuildContext context) {
    final range = '${TextNormalizer.toPersianDigits(widget.min)} تا ${TextNormalizer.toPersianDigits(widget.max)}';
    return SectionCard(
      title: widget.title,
      icon: widget.icon,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.description != null) ...[
              Text(
                widget.description!,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    inputFormatters: const [LatinDigitsFormatter()],
                    maxLength: widget.max.toString().length,
                    decoration: InputDecoration(
                      labelText: widget.label,
                      helperText: 'بازه مجاز: $range',
                      suffixText: widget.unit,
                      counterText: '',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < widget.min || n > widget.max) return 'عددی بین $range وارد کنید';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SendIconButton(onPressed: _send),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SendIconButton extends StatelessWidget {
  const SendIconButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DeviceCubit, DeviceState, bool>(
      selector: (s) => s.canSend,
      builder: (context, canSend) => SizedBox(
        width: 56,
        height: 56,
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(56, 56),
            backgroundColor: AppColors.primary,
          ),
          onPressed: canSend ? onPressed : null,
          child: const Icon(Icons.send_rounded),
        ),
      ),
    );
  }
}

class SendButton extends StatelessWidget {
  const SendButton({super.key, required this.onPressed, this.label = 'ارسال دستور'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DeviceCubit, DeviceState, bool>(
      selector: (s) => s.canSend,
      builder: (context, canSend) =>
          GradientButton(label: label, icon: Icons.send_rounded, onPressed: canSend ? onPressed : null),
    );
  }
}

/// Picks one integer from [options]; used for zone/output/part numbers.
class NumberChoice extends StatelessWidget {
  const NumberChoice({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<int> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(TextNormalizer.toPersianDigits(o)),
                selected: o == value,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: o == value ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => onChanged(o),
              ),
          ],
        ),
      ],
    );
  }
}

/// Four toggle chips forming a zone access code (zone 1 is the leftmost digit).
class ZoneSelector extends StatelessWidget {
  const ZoneSelector({super.key, required this.value, required this.onChanged, this.label = 'زون‌های مجاز'});

  final ZoneMask value;
  final ValueChanged<ZoneMask> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            CodeChip(value.code),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var z = 1; z <= 4; z++) ...[
              Expanded(
                child: FilterChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: Text('زون ${TextNormalizer.toPersianDigits(z)}', textAlign: TextAlign.center),
                  ),
                  selected: value.zones[z - 1],
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: value.zones[z - 1] ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  onSelected: (_) => onChanged(value.toggle(z)),
                ),
              ),
              if (z < 4) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class LabeledSwitch extends StatelessWidget {
  const LabeledSwitch({super.key, required this.label, required this.value, required this.onChanged, this.icon});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: icon == null ? null : Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.label, this.helper, this.validator});

  final TextEditingController controller;
  final String label;
  final String? helper;

  /// Extra check run after the 4-digit format check passes.
  final FormFieldValidator<String>? validator;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: TextInputType.number,
      obscureText: !_visible,
      maxLength: 4,
      textDirection: TextDirection.ltr,
      inputFormatters: const [LatinDigitsFormatter()],
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        counterText: '',
        prefixIcon: const Icon(Icons.password),
        suffixIcon: IconButton(
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
      validator: (v) {
        if (!RegExp(r'^\d{4}$').hasMatch(v ?? '')) return 'رمز باید ۴ رقم باشد';
        return widget.validator?.call(v);
      },
    );
  }
}
