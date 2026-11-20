import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../core/widgets/common.dart';
import '../../../gsa212/presentation/widgets/settings_widgets.dart';
import '../../domain/repositories/device_repository.dart';
import '../cubit/device_cubit.dart';

class EditDevicePage extends StatefulWidget {
  const EditDevicePage({super.key});

  @override
  State<EditDevicePage> createState() => _EditDevicePageState();
}

class _EditDevicePageState extends State<EditDevicePage> {
  final _formKey = GlobalKey<FormState>();
  late final DeviceState _initial = context.read<DeviceCubit>().state;
  late final _name = TextEditingController(text: _initial.device.name);
  late final _sim = TextEditingController(text: _initial.device.simNumber);
  late final _owner = TextEditingController(text: _initial.device.ownerPhone);
  late final _password = TextEditingController(text: _initial.password);
  String? _simError;

  @override
  void dispose() {
    _name.dispose();
    _sim.dispose();
    _owner.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<DeviceCubit>();
    final duplicate = await sl<DeviceRepository>().findBySender(_sim.text);
    setState(
      () => _simError = duplicate != null && duplicate.id != _initial.device.id
          ? 'این شماره برای دستگاه «${duplicate.name}» ثبت شده است'
          : null,
    );
    if (!_formKey.currentState!.validate() || _simError != null) return;
    await cubit.updateDevice(
      name: _name.text.trim(),
      simNumber: PhoneUtils.normalize(_sim.text),
      ownerPhone: _owner.text.trim().isEmpty ? null : PhoneUtils.normalize(_owner.text),
    );
    if (_password.text != _initial.password) await cubit.updatePassword(_password.text);
    if (!mounted) return;
    showAppSnack(context, 'اطلاعات دستگاه ذخیره شد');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'حذف دستگاه',
      message: 'دستگاه «${_initial.device.name}» و تاریخچه آن از برنامه حذف شود؟ تنظیمات خود دستگاه تغییری نمی‌کند.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (ok && mounted) await context.read<DeviceCubit>().delete();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'ویرایش دستگاه',
      children: [
        Form(
          key: _formKey,
          child: SectionCard(
            title: 'اطلاعات دستگاه',
            icon: Icons.edit_outlined,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'نام دستگاه',
                    prefixIcon: Icon(Icons.label_outline),
                    counterText: '',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'نام دستگاه را وارد کنید' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _sim,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: const [LatinDigitsFormatter(allowed: r'0-9+')],
                  decoration: InputDecoration(
                    labelText: 'شماره سیم‌کارت دستگاه',
                    prefixIcon: const Icon(Icons.sim_card_outlined),
                    errorText: _simError,
                  ),
                  validator: (v) => PhoneUtils.isValidMobile(v ?? '') ? null : 'شماره موبایل معتبر وارد کنید',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _owner,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: const [LatinDigitsFormatter(allowed: r'0-9+')],
                  decoration: const InputDecoration(
                    labelText: 'شماره مدیر (اختیاری)',
                    prefixIcon: Icon(Icons.phone_iphone),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    return value.isEmpty || PhoneUtils.isValidMobile(value) ? null : 'شماره موبایل معتبر وارد کنید';
                  },
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  label: 'رمز کنترلی ذخیره‌شده',
                  helper: 'فقط رمز ذخیره‌شده در برنامه تغییر می‌کند، نه روی دستگاه',
                ),
                const SizedBox(height: 18),
                GradientButton(label: 'ذخیره', icon: Icons.save_outlined, onPressed: _save),
              ],
            ),
          ),
        ),
        SectionCard(
          title: 'حذف دستگاه',
          icon: Icons.delete_outline,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: _delete,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('حذف دستگاه از برنامه'),
          ),
        ),
      ],
    );
  }
}
