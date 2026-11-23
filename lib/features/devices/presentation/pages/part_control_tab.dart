import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/common.dart';
import '../../../gsa212/domain/gsa212_commands.dart';
import '../../../gsa212/presentation/pages/settings_pages.dart';
import '../../../gsa212/presentation/widgets/settings_widgets.dart';
import '../cubit/device_cubit.dart';
import '../widgets/send_feedback.dart';
import 'device_page.dart';

/// Arms/disarms each partition part with its own control password (V command).
class PartControlTab extends StatelessWidget {
  const PartControlTab({super.key});

  @override
  Widget build(BuildContext context) {
    final partitionOn = context.select<DeviceCubit, bool?>((c) => c.state.configValue<bool>(ConfigKeys.partitionMode));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (partitionOn != true) ...[
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => pushWithDevice(context, const PartitionsPage()),
            child: InfoBanner(
              icon: Icons.account_tree_outlined,
              color: const Color(0xFFB7791F),
              text: partitionOn == false
                  ? 'پارتیشن‌بندی دستگاه غیرفعال است. برای کنترل جداگانه قسمت‌ها، ابتدا آن را در تنظیمات > پارتیشن‌بندی فعال کنید.'
                  : 'برای کنترل جداگانه قسمت‌ها، پارتیشن‌بندی باید در تنظیمات > پارتیشن‌بندی فعال و زون‌های هر قسمت تعریف شده باشد.',
            ),
          ),
          const SizedBox(height: 14),
        ],
        for (var part = 1; part <= 4; part++) ...[_PartCard(part: part), const SizedBox(height: 14)],
      ],
    );
  }
}

class _PartCard extends StatefulWidget {
  const _PartCard({required this.part});

  final int part;

  @override
  State<_PartCard> createState() => _PartCardState();
}

class _PartCardState extends State<_PartCard> {
  final _formKey = GlobalKey<FormState>();
  late final _password = TextEditingController(text: _saved);

  String get _saved => context.read<DeviceCubit>().state.partPasswords[widget.part] ?? '';

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _send(bool arm) {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<DeviceCubit>();
    sendDeviceCommand(
      context,
      cubit,
      cubit.state.commands.partControl(part: widget.part, arm: arm, partPassword: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeviceCubit, DeviceState>(
      listenWhen: (prev, next) => prev.partPasswords[widget.part] != next.partPasswords[widget.part],
      listener: (context, state) => _password.text = state.partPasswords[widget.part] ?? _password.text,
      child: SectionCard(
        title: 'قسمت ${TextNormalizer.toPersianDigits(widget.part)}',
        icon: Icons.shield_outlined,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                controller: _password,
                label: 'رمز کنترلی قسمت',
                helper: _saved.isEmpty ? null : 'رمز ذخیره‌شده در برنامه وارد شده است',
              ),
              const SizedBox(height: 14),
              BlocSelector<DeviceCubit, DeviceState, bool>(
                selector: (s) => s.canSend,
                builder: (context, canSend) => Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: canSend ? () => _send(true) : null,
                        icon: const Icon(Icons.lock_rounded),
                        label: const Text('فعال'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                        onPressed: canSend ? () => _send(false) : null,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('غیرفعال'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
