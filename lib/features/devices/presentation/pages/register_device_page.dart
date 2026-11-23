import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/permissions/permission_sheet.dart';
import '../../../../core/platform/sms_gateway.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/pin_pad.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../gsa212/domain/gsa212_commands.dart';
import '../../domain/usecases/send_device_command.dart';
import '../cubit/register_device_cubit.dart';
import '../widgets/send_feedback.dart';
import '../widgets/sim_slot_selector.dart';

class RegisterDevicePage extends StatelessWidget {
  const RegisterDevicePage({super.key, required this.withAppSecurity});

  final bool withAppSecurity;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          RegisterDeviceCubit(withAppSecurity: withAppSecurity, devices: sl(), auth: sl(), sendCommand: sl())..init(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  static const _stepLabels = {
    RegisterStep.device: 'اطلاعات دستگاه',
    RegisterStep.pin: 'رمز ورود',
    RegisterStep.confirmPin: 'تکرار رمز',
    RegisterStep.security: 'امنیت',
  };

  void _onResult(BuildContext context, RegisterState state) {
    final result = state.result!;
    final outcome = result.registrationSms;
    final message = switch (outcome?.status) {
      null => 'دستگاه «${result.device.name}» ثبت شد',
      SendStatus.sent => 'دستگاه ثبت شد و پیامک ثبت شماره شما ارسال شد',
      SendStatus.openedComposer => 'دستگاه ثبت شد؛ پیامک آماده‌شده را در پیام‌رسان ارسال کنید',
      _ => 'دستگاه ثبت شد، اما ارسال پیامک ثبت شماره انجام نشد',
    };
    final error = outcome != null && !outcome.delivered;
    if (state.withAppSecurity) {
      context.read<AuthBloc>().add(const AuthRegistered());
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop();
    }
    if (outcome != null && error) {
      SendFeedback.showRoot(message, error: true);
    } else {
      SendFeedback.showRoot(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterDeviceCubit, RegisterState>(
      listenWhen: (prev, next) => prev.result == null && next.result != null,
      listener: _onResult,
      builder: (context, state) {
        final cubit = context.read<RegisterDeviceCubit>();
        final isPinStep = state.step == RegisterStep.pin || state.step == RegisterStep.confirmPin;
        return PopScope(
          canPop: state.step == RegisterStep.device && !state.submitting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !state.submitting) cubit.back();
          },
          child: Scaffold(
            backgroundColor: isPinStep ? AppColors.primary : AppColors.background,
            body: isPinStep
                ? GradientBackground(child: _PinStep(state: state))
                : Column(
                    children: [
                      _Header(state: state, labels: _stepLabels),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: state.step == RegisterStep.device
                              ? _DeviceForm(key: const ValueKey('device'), state: state)
                              : _SecurityStep(key: const ValueKey('security'), state: state),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.labels});

  final RegisterState state;
  final Map<RegisterStep, String> labels;

  @override
  Widget build(BuildContext context) {
    final steps = state.steps;
    final current = steps.indexOf(state.step);
    return GradientHeader(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: state.submitting ? null : () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      state.withAppSecurity ? 'ثبت اولین دستگاه' : 'افزودن دستگاه جدید',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              if (steps.length > 1) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (var i = 0; i < steps.length; i++) ...[
                        Expanded(
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 5,
                                decoration: BoxDecoration(
                                  color: i <= current ? Colors.white : Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                labels[steps[i]]!,
                                style: TextStyle(
                                  color: i <= current ? Colors.white : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < steps.length - 1) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceForm extends StatefulWidget {
  const _DeviceForm({super.key, required this.state});

  final RegisterState state;

  @override
  State<_DeviceForm> createState() => _DeviceFormState();
}

class _DeviceFormState extends State<_DeviceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.state.draft?.name);
  late final _sim = TextEditingController(text: widget.state.draft?.simNumber);
  late final _password = TextEditingController(text: widget.state.draft?.password ?? '0000');
  late final _owner = TextEditingController(text: widget.state.draft?.ownerPhone);
  late bool _saveOwner = widget.state.draft?.saveOwnerToMemory ?? true;
  late int? _simSlot = widget.state.draft?.simSlot;
  final bool _selectSim = sl<SmsGateway>().supportsSimSelection;
  bool _showPassword = false;
  String? _simError;
  bool _checking = false;

  @override
  void dispose() {
    _name.dispose();
    _sim.dispose();
    _password.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cubit = context.read<RegisterDeviceCubit>();
    setState(() {
      _simError = null;
      _checking = true;
    });
    final duplicate = await cubit.validateSimNumber(_sim.text);
    if (!mounted) return;
    setState(() {
      _simError = duplicate;
      _checking = false;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    // Adding a device finishes right away, so its permissions are settled here; first-run asks on the last step.
    if (!widget.state.withAppSecurity && !await ensureSendPermissions(context, simSlot: _simSlot)) return;
    if (!mounted) return;
    cubit.submitDevice(
      DeviceDraft(
        name: _name.text.trim(),
        simNumber: _sim.text,
        password: _password.text,
        ownerPhone: _owner.text,
        saveOwnerToMemory: _saveOwner && _owner.text.trim().isNotEmpty,
        simSlot: _simSlot,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitting = widget.state.submitting;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          SectionCard(
            title: 'مشخصات دستگاه',
            icon: Icons.router_outlined,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'نام دستگاه',
                    hintText: 'مثلا: منزل، مغازه، انبار',
                    prefixIcon: Icon(Icons.label_outline),
                    counterText: '',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'نام دستگاه را وارد کنید' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _sim,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  textDirection: TextDirection.ltr,
                  inputFormatters: const [LatinDigitsFormatter(allowed: r'0-9+')],
                  decoration: InputDecoration(
                    labelText: 'شماره سیم‌کارت دستگاه',
                    hintText: '09xxxxxxxxx',
                    prefixIcon: const Icon(Icons.sim_card_outlined),
                    errorText: _simError,
                  ),
                  validator: (v) => PhoneUtils.isValidMobile(v ?? '') ? null : 'شماره موبایل معتبر وارد کنید',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  keyboardType: TextInputType.number,
                  obscureText: !_showPassword,
                  maxLength: 4,
                  textDirection: TextDirection.ltr,
                  inputFormatters: const [LatinDigitsFormatter()],
                  decoration: InputDecoration(
                    labelText: 'رمز کنترلی دستگاه',
                    helperText: 'رمز پیش‌فرض دستگاه ۰۰۰۰ است',
                    prefixIcon: const Icon(Icons.password),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (v) => Gsa212Commands.isValidPassword(v ?? '') ? null : 'رمز دستگاه باید ۴ رقم باشد',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'شماره مدیر دستگاه',
            icon: Icons.admin_panel_settings_outlined,
            child: Column(
              children: [
                TextFormField(
                  controller: _owner,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: const [LatinDigitsFormatter(allowed: r'0-9+')],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'شماره موبایل شما',
                    hintText: '09xxxxxxxxx',
                    prefixIcon: Icon(Icons.phone_iphone),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    return PhoneUtils.isValidMobile(value) ? null : 'شماره موبایل معتبر وارد کنید';
                  },
                ),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _saveOwner && _owner.text.trim().isNotEmpty,
                  onChanged: _owner.text.trim().isEmpty ? null : (v) => setState(() => _saveOwner = v),
                  title: const Text('ثبت شماره من در حافظه ۱ دستگاه', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'حافظه ۱ مربوط به مدیر است و پیامک‌های هشدار و گزارش شارژ به آن ارسال می‌شود',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          if (_selectSim) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'سیم‌کارت ارسال دستور',
              icon: Icons.sim_card_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'دستورات این دستگاه همیشه از این سیم‌کارت گوشی شما ارسال می‌شوند.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
                  ),
                  const SizedBox(height: 12),
                  SimSlotSelector(value: _simSlot, onChanged: (v) => setState(() => _simSlot = v)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const InfoBanner(
            text:
                'قبل از استفاده، کد PIN سیم‌کارت دستگاه را غیرفعال و زبان آن را انگلیسی کنید. '
                'بین پیامک‌های ارسالی به دستگاه فاصله زمانی لازم است که در تنظیمات برنامه قابل تغییر است.',
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: widget.state.withAppSecurity ? 'ادامه' : 'ثبت دستگاه',
            icon: widget.state.withAppSecurity ? Icons.arrow_forward : Icons.check_circle_outline,
            loading: _checking || submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _PinStep extends StatelessWidget {
  const _PinStep({required this.state});

  final RegisterState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegisterDeviceCubit>();
    final confirming = state.step == RegisterStep.confirmPin;
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(color: Colors.white, icon: const Icon(Icons.arrow_back), onPressed: cubit.back),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15)),
                      child: Icon(
                        confirming ? Icons.verified_user_outlined : Icons.lock_outline,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      confirming ? 'رمز ورود را دوباره وارد کنید' : 'یک رمز ۴ رقمی برای ورود به برنامه بسازید',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 20,
                      child: Text(
                        state.pinMismatchTick > 0 && !confirming
                            ? 'رمزها یکسان نبودند، دوباره تلاش کنید'
                            : 'این رمز با رمز دستگاه متفاوت است',
                        style: TextStyle(
                          color: state.pinMismatchTick > 0 && !confirming ? const Color(0xFFFFCDD2) : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    PinPad(
                      key: ValueKey(state.step),
                      errorTick: state.pinMismatchTick,
                      onCompleted: confirming ? cubit.confirmPin : cubit.submitPin,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityStep extends StatelessWidget {
  const _SecurityStep({super.key, required this.state});

  final RegisterState state;

  Future<void> _finish(BuildContext context) async {
    final cubit = context.read<RegisterDeviceCubit>();
    if (!await ensureSendPermissions(context, simSlot: state.draft!.simSlot) || !context.mounted) return;
    if (state.enableBiometric && state.biometricAvailable) {
      if (!await ensureAppPermission(context, AppPermission.biometric)) return;
    }
    await cubit.finish();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegisterDeviceCubit>();
    final draft = state.draft!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        SectionCard(
          title: 'ورود با اثر انگشت',
          icon: Icons.fingerprint,
          child: state.biometricAvailable
              ? SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: state.enableBiometric,
                  onChanged: cubit.setBiometric,
                  title: const Text('فعال‌سازی ورود با اثر انگشت', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'در کنار رمز ۴ رقمی می‌توانید با اثر انگشت وارد شوید',
                    style: TextStyle(fontSize: 12),
                  ),
                )
              : const Text(
                  'اثر انگشت روی این گوشی فعال یا پشتیبانی نشده است؛ ورود با رمز ۴ رقمی انجام می‌شود.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.7),
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'خلاصه ثبت',
          icon: Icons.fact_check_outlined,
          child: Column(
            children: [
              _SummaryRow(label: 'نام دستگاه', value: draft.name),
              _SummaryRow(label: 'شماره سیم‌کارت', value: PhoneUtils.normalize(draft.simNumber), ltr: true),
              _SummaryRow(label: 'مدل', value: Gsa212Commands.model, ltr: true),
              if (draft.simSlot != null) _SummaryRow(label: 'سیم‌کارت ارسال', value: 'سیم ${draft.simSlot! + 1}'),
              if (draft.saveOwnerToMemory)
                _SummaryRow(label: 'ثبت در حافظه ۱', value: PhoneUtils.normalize(draft.ownerPhone), ltr: true),
            ],
          ),
        ),
        if (draft.saveOwnerToMemory) ...[
          const SizedBox(height: 16),
          const InfoBanner(
            text: 'با تکمیل ثبت، پیامک ذخیره شماره شما در حافظه ۱ دستگاه ارسال می‌شود.',
            icon: Icons.sms_outlined,
          ),
        ],
        const SizedBox(height: 24),
        GradientButton(
          label: 'تکمیل ثبت',
          icon: Icons.check_circle_outline,
          loading: state.submitting,
          onPressed: () => _finish(context),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(
            ltr ? value : TextNormalizer.toPersianDigits(value),
            textDirection: ltr ? TextDirection.ltr : null,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
