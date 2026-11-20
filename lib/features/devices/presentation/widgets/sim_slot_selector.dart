import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/permissions/permission_sheet.dart';
import '../../../../core/platform/sms_gateway.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/text_normalizer.dart';

/// Lets the user pick which phone SIM (slot 1 or 2) sends commands to a device. Android only.
class SimSlotSelector extends StatefulWidget {
  const SimSlotSelector({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  State<SimSlotSelector> createState() => _SimSlotSelectorState();
}

class _SimSlotSelectorState extends State<SimSlotSelector> {
  final SmsGateway _gateway = sl();
  List<SimCard>? _cards;
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cards = await _gateway.simCards();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _denied = cards == null;
      _cards = cards ?? const [SimCard(slot: 0), SimCard(slot: 1)];
    });
    final active = _cards!.where((c) => c.active).toList();
    final current = widget.value;
    final currentInactive = current != null && !_denied && !active.any((c) => c.slot == current);
    if ((current == null || currentInactive) && active.isNotEmpty) widget.onChanged(active.first.slot);
    if (current == null && _denied) widget.onChanged(0);
  }

  Future<void> _requestAccess() async {
    if (await ensureAppPermission(context, AppPermission.phone) && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tiles always share one height, whatever details each SIM exposes.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in _cards!) ...[
                Expanded(
                  child: _SimTile(
                    card: card,
                    known: !_denied,
                    selected: widget.value == card.slot,
                    onTap: () => widget.onChanged(card.slot),
                  ),
                ),
                if (card.slot == 0) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
        if (_denied) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'برای نمایش اپراتور و شماره هر سیم‌کارت، اجازه دسترسی به تلفن را بدهید.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                ),
              ),
              TextButton(onPressed: _requestAccess, child: const Text('اجازه دسترسی')),
            ],
          ),
        ],
      ],
    );
  }
}

class _SimTile extends StatelessWidget {
  const _SimTile({required this.card, required this.known, required this.selected, required this.onTap});

  final SimCard card;
  final bool known;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = !known || card.active;
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final subtitle = !known
        ? 'اپراتور نامشخص'
        : card.active
        ? card.carrier ?? 'فعال'
        : 'بدون سیم‌کارت';
    final number = card.number ?? (known && !card.active ? '' : 'شماره نامشخص');
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sim_card_rounded, color: color, size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'سیم ${TextNormalizer.toPersianDigits(card.slot + 1)}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: color),
                      ),
                    ),
                    Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: color, size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(
                  number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: card.number != null ? TextDirection.ltr : null,
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
