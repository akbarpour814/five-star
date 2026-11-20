import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../gsa212/domain/gsa212_response_parser.dart';
import '../../domain/entities/device_message.dart';
import '../cubit/device_cubit.dart';

/// iOS / web: the user copies the device reply from their messaging app and pastes it here.
class PasteResponsePage extends StatefulWidget {
  const PasteResponsePage({super.key});

  @override
  State<PasteResponsePage> createState() => _PasteResponsePageState();
}

class _PasteResponsePageState extends State<PasteResponsePage> {
  final _controller = TextEditingController();
  ParsedResponse? _preview;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final text = _controller.text.trim();
    setState(() => _preview = text.isEmpty ? null : context.read<DeviceCubit>().preview(text));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      showAppSnack(context, 'کلیپ‌بورد خالی است؛ ابتدا متن پیامک دستگاه را کپی کنید', error: true);
      return;
    }
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    final parsed = await context.read<DeviceCubit>().ingest(text);
    if (!mounted) return;
    showAppSnack(context, parsed.recognized ? 'پاسخ ثبت شد: ${parsed.title}' : 'پیام در تاریخچه دستگاه ثبت شد');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<DeviceCubit, String>((c) => c.state.device.name);
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
                          const Text(
                            'ثبت پاسخ دستگاه',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          Text(name, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const SectionCard(
                  title: 'چطور پاسخ را ثبت کنم؟',
                  icon: Icons.lightbulb_outline_rounded,
                  child: Column(
                    children: [
                      _Step(
                        number: '۱',
                        icon: Icons.sms_outlined,
                        text: 'برنامه پیام‌ها را باز کنید و پیامک دستگاه را پیدا کنید.',
                      ),
                      _Step(
                        number: '۲',
                        icon: Icons.touch_app_outlined,
                        text: 'روی پیامک انگشت را نگه دارید و «کپی» را بزنید.',
                      ),
                      _Step(
                        number: '۳',
                        icon: Icons.content_paste_rounded,
                        text: 'به برنامه برگردید و دکمه «چسباندن» را بزنید.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'متن پیامک دستگاه',
                  icon: Icons.message_outlined,
                  trailing: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'پاک کردن',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: _controller.clear,
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _controller,
                        minLines: 4,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          hintText: 'متن پیامک دریافتی از دستگاه را اینجا قرار دهید…',
                          fillColor: AppColors.background,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('چسباندن از کلیپ‌بورد'),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _preview == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(_preview!.title),
                          padding: const EdgeInsets.only(top: 14),
                          child: _PreviewCard(preview: _preview!),
                        ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'ثبت پاسخ',
                  icon: Icons.check_circle_outline,
                  loading: _saving,
                  onPressed: _controller.text.trim().isEmpty ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.icon, required this.text});

  final String number;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 20, color: AppColors.sky),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.6))),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final ParsedResponse preview;

  @override
  Widget build(BuildContext context) {
    final color = !preview.recognized
        ? AppColors.textSecondary
        : preview.severity == MessageSeverity.alert
        ? AppColors.danger
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            !preview.recognized
                ? Icons.help_outline_rounded
                : preview.severity == MessageSeverity.alert
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.recognized ? 'تشخیص داده شد' : 'پیام ناشناخته',
                  style: TextStyle(fontSize: 11.5, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  preview.recognized ? preview.title : 'این پیام به‌صورت متن خام در تاریخچه ثبت می‌شود',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14.5),
                ),
                if (preview.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(preview.detail!, style: const TextStyle(fontSize: 12.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
