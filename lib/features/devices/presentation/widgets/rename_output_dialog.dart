import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/common.dart';

/// Returns the new name, an empty string to restore the default, or null when cancelled.
Future<String?> showRenameOutputDialog(
  BuildContext context, {
  required int output,
  required String currentName,
  required String? customName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameOutputDialog(output: output, currentName: currentName, customName: customName),
  );
}

class _RenameOutputDialog extends StatefulWidget {
  const _RenameOutputDialog({required this.output, required this.currentName, required this.customName});

  final int output;
  final String currentName;
  final String? customName;

  @override
  State<_RenameOutputDialog> createState() => _RenameOutputDialogState();
}

class _RenameOutputDialogState extends State<_RenameOutputDialog> {
  static const _maxLength = 24;
  static const _suggestions = ['درب پارکینگ', 'درب حیاط', 'روشنایی', 'کرکره', 'پمپ آب', 'سیستم گرمایش'];

  // Owned by this State so it outlives the dialog's closing animation.
  late final _controller = TextEditingController(text: widget.customName ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  void _useSuggestion(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.output == 1 ? Icons.door_sliding_outlined : Icons.power_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نام خروجی ${TextNormalizer.toPersianDigits(widget.output)}',
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'نامی بگذارید که کاربرد خروجی را نشان دهد',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLength: _maxLength,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        labelText: 'نام خروجی',
                        hintText: widget.currentName,
                        prefixIcon: const Icon(Icons.label_outline),
                        counterText:
                            '${TextNormalizer.toPersianDigits(value.text.length)} / ${TextNormalizer.toPersianDigits(_maxLength)}',
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'پاک کردن',
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: _controller.clear,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('پیشنهادها', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(
                          label: Text(s),
                          backgroundColor: AppColors.ice,
                          side: BorderSide.none,
                          labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12.5),
                          onPressed: () => _useSuggestion(s),
                        ),
                    ],
                  ),
                  if (widget.customName != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context, ''),
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('بازگشت به نام پیش‌فرض'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('انصراف'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientButton(label: 'ذخیره', icon: Icons.check_rounded, onPressed: _save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
