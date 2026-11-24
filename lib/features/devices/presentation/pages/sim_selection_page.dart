import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/common.dart';
import '../../../panel/presentation/widgets/settings_widgets.dart';
import '../cubit/device_cubit.dart';
import '../widgets/sim_slot_selector.dart';

class SimSelectionPage extends StatelessWidget {
  const SimSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'سیم‌کارت ارسال دستور',
      children: [
        SectionCard(
          title: 'انتخاب سیم‌کارت',
          icon: Icons.sim_card_outlined,
          child: BlocSelector<DeviceCubit, DeviceState, int?>(
            selector: (s) => s.device.simSlot,
            builder: (context, slot) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'دستورات این دستگاه همیشه از سیم‌کارت انتخاب‌شده گوشی شما ارسال می‌شوند.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
                ),
                const SizedBox(height: 12),
                SimSlotSelector(
                  value: slot,
                  onChanged: (value) async {
                    if (value == slot) return;
                    await context.read<DeviceCubit>().updateSimSlot(value);
                    if (context.mounted) {
                      showAppSnack(
                        context,
                        'ارسال دستورات از سیم ${TextNormalizer.toPersianDigits(value + 1)} انجام می‌شود',
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const InfoBanner(
          text: 'اگر شماره سیم‌کارت نمایش داده نمی‌شود، اپراتور آن را روی سیم‌کارت ذخیره نکرده است؛ از روی نام اپراتور انتخاب کنید.',
        ),
      ],
    );
  }
}
