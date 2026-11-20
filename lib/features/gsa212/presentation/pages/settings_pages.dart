import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/common.dart';
import '../../../devices/presentation/cubit/device_cubit.dart';
import '../../../devices/presentation/widgets/send_feedback.dart';
import '../../domain/device_command.dart';
import '../../domain/gsa212_commands.dart';
import '../widgets/settings_widgets.dart';

String _fa(Object v) => TextNormalizer.toPersianDigits(v);

// ============================================================ Phone memories (E / C)

class PhoneMemoriesPage extends StatelessWidget {
  const PhoneMemoriesPage({super.key});

  static const _groups = [
    (1, 10, 'ارسال پیامک', Icons.sms_outlined),
    (11, 20, 'تماس با خط تلفن', Icons.phone_outlined),
    (21, 30, 'تماس با سیم‌کارت', Icons.phone_android_outlined),
  ];

  Future<void> _edit(BuildContext context, int memory, String? current) async {
    final phone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemorySheet(memory: memory, current: current),
    );
    if (phone == null || !context.mounted) return;
    final c = context.read<DeviceCubit>().state.commands;
    await sendFromSettings(context, c.saveNumber(memory: memory, phone: phone));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceCubit, DeviceState>(
      builder: (context, state) => SettingsScaffold(
        title: 'حافظه‌های تلفن',
        children: [
          const InfoBanner(
            text:
                'حافظه ۱ تا ۱۰ پیامک هشدار دریافت می‌کنند، ۱۱ تا ۲۰ با خط تلفن و ۲۱ تا ۳۰ با سیم‌کارت تماس گرفته می‌شوند. '
                'حافظه ۱ مدیر دستگاه است. در سطح امنیت بالا فقط حافظه ۱ تا ۴ امکان کنترل دارند.',
          ),
          SectionCard(
            title: 'استعلام حافظه‌ها',
            icon: Icons.manage_search_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'شماره‌های ذخیره‌شده در دستگاه را دریافت کنید تا در لیست زیر نمایش داده شوند.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
                ),
                const SizedBox(height: 12),
                SendButton(
                  label: 'استعلام حافظه‌ها',
                  onPressed: () => sendFromSettings(context, state.commands.memories()),
                ),
              ],
            ),
          ),
          for (final g in _groups)
            SectionCard(
              title: 'حافظه ${_fa(g.$1)} تا ${_fa(g.$2)} • ${g.$3}',
              icon: g.$4,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  for (var m = g.$1; m <= g.$2; m++)
                    _MemoryTile(
                      memory: m,
                      number: state.status.memories[m],
                      onTap: () => _edit(context, m, state.status.memories[m]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory, required this.number, required this.onTap});

  final int memory;
  final String? number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = number == null || number!.isEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: memory == 1 ? AppColors.brandRed : AppColors.ice,
        child: Text(
          _fa(memory),
          style: TextStyle(
            color: memory == 1 ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(
        empty ? (number == null ? 'نامشخص' : 'خالی') : number!,
        textDirection: empty ? null : TextDirection.ltr,
        textAlign: TextAlign.start,
        style: TextStyle(
          color: empty ? AppColors.textSecondary : AppColors.textPrimary,
          fontWeight: empty ? FontWeight.w400 : FontWeight.w700,
        ),
      ),
      subtitle: memory == 1 ? const Text('مدیر', style: TextStyle(fontSize: 11)) : null,
      trailing: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
      onTap: onTap,
    );
  }
}

class _MemorySheet extends StatefulWidget {
  const _MemorySheet({required this.memory, this.current});

  final int memory;
  final String? current;

  @override
  State<_MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends State<_MemorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landline = widget.memory >= 11 && widget.memory <= 20;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ثبت شماره در حافظه ${_fa(widget.memory)}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              inputFormatters: const [LatinDigitsFormatter(allowed: r'0-9+')],
              decoration: InputDecoration(
                labelText: landline ? 'شماره تلفن (ثابت یا همراه)' : 'شماره موبایل',
                hintText: landline ? '021xxxxxxxx' : '09xxxxxxxxx',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              validator: (v) {
                final value = v ?? '';
                if (landline) return PhoneUtils.isValidAnyNumber(value) ? null : 'شماره معتبر وارد کنید';
                return PhoneUtils.isValidMobile(value) ? null : 'شماره موبایل معتبر وارد کنید';
              },
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'ادامه',
              icon: Icons.arrow_forward,
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context, PhoneUtils.normalize(_controller.text));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ Device password (0)

class DevicePasswordPage extends StatefulWidget {
  const DevicePasswordPage({super.key});

  @override
  State<DevicePasswordPage> createState() => _DevicePasswordPageState();
}

class _DevicePasswordPageState extends State<DevicePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<DeviceCubit>();
    final outcome = await sendDeviceCommand(
      context,
      cubit,
      cubit.state.commands.changePassword(_next.text),
      sender: () => cubit.changePassword(_next.text),
    );
    if (outcome != null && outcome.delivered && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'رمز دستگاه',
      children: [
        const InfoBanner(
          text:
              'رمز کنترلی دستگاه برای تمام دستورات پیامکی و کنترل با تماس استفاده می‌شود و با رمز ورود برنامه متفاوت است. '
              'پس از ارسال، رمز جدید برای دستورات بعدی در برنامه ذخیره می‌شود.',
        ),
        SectionCard(
          title: 'تغییر رمز کنترلی',
          icon: Icons.password_rounded,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PasswordField(controller: _next, label: 'رمز جدید ۴ رقمی'),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textDirection: TextDirection.ltr,
                  inputFormatters: const [LatinDigitsFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'تکرار رمز جدید',
                    counterText: '',
                    prefixIcon: Icon(Icons.password),
                  ),
                  validator: (v) => v == _next.text ? null : 'تکرار رمز با رمز جدید یکسان نیست',
                ),
                const SizedBox(height: 18),
                SendButton(label: 'ارسال دستور تغییر رمز', onPressed: _send),
              ],
            ),
          ),
        ),
        const InfoBanner(
          icon: Icons.help_outline,
          text:
              'اگر رمز دستگاه را فراموش کرده‌اید: دستگاه را خاموش کنید، دکمه RECORD را نگه دارید و روشن کنید '
              'تا رمز به ۰۰۰۰ برگردد. سپس رمز ذخیره‌شده را در «ویرایش دستگاه» اصلاح کنید.',
        ),
      ],
    );
  }
}

// ============================================================ SIM (* # G P N)

class SimSettingsPage extends StatefulWidget {
  const SimSettingsPage({super.key});

  @override
  State<SimSettingsPage> createState() => _SimSettingsPageState();
}

class _SimSettingsPageState extends State<SimSettingsPage> {
  final _charge = TextEditingController();
  final _ussd = TextEditingController();

  @override
  void dispose() {
    _charge.dispose();
    _ussd.dispose();
    super.dispose();
  }

  Widget _codeCard({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required String label,
    required String hint,
    required DeviceCommand Function(Gsa212Commands c, String value) build,
    String? description,
  }) {
    return SectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (description != null) ...[
            Text(description, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7)),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: const [LatinDigitsFormatter(allowed: r'0-9*#')],
                  decoration: InputDecoration(labelText: label, hintText: hint),
                ),
              ),
              const SizedBox(width: 10),
              SendIconButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) {
                    showAppSnack(context, '$label را وارد کنید', error: true);
                    return;
                  }
                  sendFromSettings(context, build(context.read<DeviceCubit>().state.commands, value));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<DeviceCubit>().state.commands;
    return SettingsScaffold(
      title: 'سیم‌کارت و شارژ',
      children: [
        SectionCard(
          title: 'استعلام‌ها',
          icon: Icons.manage_search_rounded,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => sendFromSettings(context, c.simBalance()),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('شارژ سیم‌کارت'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => sendFromSettings(context, c.antenna()),
                  icon: const Icon(Icons.signal_cellular_alt_rounded),
                  label: const Text('قدرت آنتن'),
                ),
              ),
            ],
          ),
        ),
        _codeCard(
          title: 'شارژ سیم‌کارت',
          icon: Icons.add_card_outlined,
          controller: _charge,
          label: 'رمز شارژ',
          hint: 'کد کارت شارژ',
          description: 'رمز کارت شارژ را وارد کنید تا سیم‌کارت دستگاه شارژ شود.',
          build: (c, v) => c.simCharge(v),
        ),
        _codeCard(
          title: 'اجرای کد USSD',
          icon: Icons.dialpad_rounded,
          controller: _ussd,
          label: 'کد USSD',
          hint: '*141#',
          description: 'دستگاه کد را اجرا کرده و نتیجه را پیامک می‌کند.',
          build: (c, v) => c.ussd(v),
        ),
        NumberSettingCard(
          title: 'استعلام شارژ خودکار',
          icon: Icons.autorenew_rounded,
          label: 'تعداد پیامک',
          min: 1,
          max: 255,
          configKey: ConfigKeys.autoBalance,
          description:
              'پس از این تعداد پیامک (هر تماس یک پیامک حساب می‌شود)، دستگاه شارژ را استعلام و برای مدیر ارسال می‌کند.',
          command: (s, v) => s.commands.autoBalance(v),
        ),
      ],
    );
  }
}

// ============================================================ Siren & sound (J M)

class SirenSoundPage extends StatelessWidget {
  const SirenSoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'آژیر و صدا',
      children: [
        NumberSettingCard(
          title: 'زمان آژیر',
          icon: Icons.timer_outlined,
          label: 'مدت آژیر',
          unit: 'ثانیه',
          min: 0,
          max: 255,
          configKey: ConfigKeys.sirenTime,
          description: 'مدت زمانی که پس از تحریک، آژیر به صدا درمی‌آید.',
          command: (s, v) => s.commands.sirenTime(v),
        ),
        BlocBuilder<DeviceCubit, DeviceState>(
          builder: (context, state) {
            final current = state.configValue<int>(ConfigKeys.soundMode);
            return SectionCard(
              title: 'حالت تک‌آژیر (صدای فعال/غیرفعال شدن)',
              icon: Icons.volume_up_outlined,
              child: Column(
                children: [
                  for (final mode in SoundMode.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OptionTile(
                        title: mode.label,
                        selected: current == mode.code,
                        onTap: () => sendFromSettings(context, state.commands.soundMode(mode)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.title, required this.selected, required this.onTap});

  final String title;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))],
                ),
              ),
              const Icon(Icons.send_rounded, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================ Security & reports (K H I O T @ Q)

class SecurityReportsPage extends StatelessWidget {
  const SecurityReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'سطح امنیت و گزارش‌ها',
      children: [
        ToggleSettingCard(
          title: 'سطح امنیت',
          icon: Icons.verified_user_outlined,
          configKey: ConfigKeys.securityHigh,
          onLabel: 'بالا',
          offLabel: 'متوسط',
          description:
              'امنیت بالا: فقط شماره‌های حافظه ۱ تا ۴ دستگاه را کنترل می‌کنند. '
              'امنیت متوسط: هر شخصی که شماره سیم‌کارت و رمز را دارد.',
          command: (s, v) => s.commands.securityLevel(high: v),
        ),
        ToggleSettingCard(
          title: 'گزارش ریموت',
          icon: Icons.settings_remote_outlined,
          configKey: ConfigKeys.remoteReport,
          description: 'ارسال پیامک گزارش هنگام استفاده از ریموت‌ها، همراه با شماره ریموت.',
          command: (s, v) => s.commands.remoteReport(v),
        ),
        ToggleSettingCard(
          title: 'گزارش برق',
          icon: Icons.power_outlined,
          configKey: ConfigKeys.powerReport,
          description: 'اطلاع‌رسانی قطع و وصل شدن برق شهر.',
          command: (s, v) => s.commands.powerReport(v),
        ),
        ToggleSettingCard(
          title: 'اخطار قطع اسپیکر',
          icon: Icons.speaker_outlined,
          configKey: ConfigKeys.speakerReport,
          onLabel: 'روشن',
          offLabel: 'خاموش',
          command: (s, v) => s.commands.speakerCutReport(v),
        ),
        ToggleSettingCard(
          title: 'اخطار قطع فیوز AUX',
          icon: Icons.electric_bolt_outlined,
          configKey: ConfigKeys.fuseReport,
          onLabel: 'روشن',
          offLabel: 'خاموش',
          command: (s, v) => s.commands.fuseReport(v),
        ),
        ToggleSettingCard(
          title: 'اخطار کم شدن باتری سنسور بی‌سیم',
          icon: Icons.battery_alert_outlined,
          configKey: ConfigKeys.sensorBattery,
          onLabel: 'روشن',
          offLabel: 'خاموش',
          description: 'فقط برای سنسورهای فایواستار؛ جامپر FAULT داخل سنسور باید روی ON باشد.',
          command: (s, v) => s.commands.sensorBatteryReport(v),
        ),
        NumberSettingCard(
          title: 'یادآوری سرویس دوره‌ای',
          icon: Icons.event_repeat_outlined,
          label: 'فاصله یادآوری',
          unit: 'روز',
          min: 1,
          max: 255,
          configKey: ConfigKeys.serviceDays,
          description: 'یادآوری پیامکی برای سرویس و تعویض باتری سنسورهای بی‌سیم.',
          command: (s, v) => s.commands.serviceReminder(v),
        ),
      ],
    );
  }
}

// ============================================================ Zones (Z)

class ZonesPage extends StatefulWidget {
  const ZonesPage({super.key});

  @override
  State<ZonesPage> createState() => _ZonesPageState();
}

class _ZonesPageState extends State<ZonesPage> {
  int _zone = 1;
  bool _nc = true;
  bool _dingDong = false;
  ZoneType _type = ZoneType.normal;
  final _delay = TextEditingController(text: '0');
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadZone(1);
  }

  @override
  void dispose() {
    _delay.dispose();
    super.dispose();
  }

  void _loadZone(int zone) {
    final saved = context.read<DeviceCubit>().state.config[ConfigKeys.zone(zone)];
    setState(() {
      _zone = zone;
      if (saved is Map) {
        _nc = saved['nc'] as bool? ?? true;
        _dingDong = saved['dingDong'] as bool? ?? false;
        _type = ZoneType.values.firstWhere((t) => t.code == saved['type'], orElse: () => ZoneType.normal);
        _delay.text = '${saved['delay'] ?? 0}';
      } else {
        _nc = true;
        _dingDong = false;
        _type = ZoneType.normal;
        _delay.text = '0';
      }
    });
  }

  void _send() {
    if (!_formKey.currentState!.validate()) return;
    final c = context.read<DeviceCubit>().state.commands;
    sendFromSettings(
      context,
      c.zoneSettings(
        zone: _zone,
        normallyClosed: _nc,
        dingDong: _dingDong,
        type: _type,
        delaySeconds: int.tryParse(_delay.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'تنظیمات زون‌ها',
      children: [
        const InfoBanner(
          text:
              'در حالت پیش‌فرض همه زون‌ها NC و معمولی هستند. نوع زون و دینگ‌دانگ روی سنسورهای بی‌سیم هم اعمال می‌شود.',
        ),
        SectionCard(
          title: 'انتخاب زون',
          icon: Icons.sensors_rounded,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NumberChoice(label: 'زون', options: const [1, 2, 3, 4], value: _zone, onChanged: _loadZone),
                const SizedBox(height: 16),
                const Text('حالت ورودی', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('NC (بسته)')),
                    ButtonSegment(value: false, label: Text('NO (باز)')),
                  ],
                  selected: {_nc},
                  onSelectionChanged: (v) => setState(() => _nc = v.first),
                ),
                const SizedBox(height: 16),
                const Text('نوع زون', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SegmentedButton<ZoneType>(
                  segments: [for (final t in ZoneType.values) ButtonSegment(value: t, label: Text(t.label))],
                  selected: {_type},
                  onSelectionChanged: (v) => setState(() => _type = v.first),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _type != ZoneType.delayed
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: TextFormField(
                            controller: _delay,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            maxLength: 3,
                            inputFormatters: const [LatinDigitsFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'زمان تاخیر',
                              suffixText: 'ثانیه',
                              helperText: 'بازه مجاز: ۱ تا ۲۵۵ ثانیه',
                              counterText: '',
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 1 || n > 255 ? 'عددی بین ۱ تا ۲۵۵ وارد کنید' : null;
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                LabeledSwitch(
                  label: 'دینگ‌دانگ',
                  icon: Icons.notifications_active_outlined,
                  value: _dingDong,
                  onChanged: (v) => setState(() => _dingDong = v),
                ),
                const SizedBox(height: 12),
                SendButton(label: 'ارسال تنظیمات زون ${_fa(_zone)}', onPressed: _send),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================ Remotes (L)

class RemotesPage extends StatefulWidget {
  const RemotesPage({super.key});

  @override
  State<RemotesPage> createState() => _RemotesPageState();
}

class _RemotesPageState extends State<RemotesPage> {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'ریموت‌ها',
      children: [
        const InfoBanner(
          text:
              'دستگاه تا ۳۰ ریموت را به ترتیب ثبت شماره‌گذاری می‌کند. شماره هر ریموت هنگام ثبت با تعداد چشمک LED لرن اعلام می‌شود. '
              'افزودن ریموت فقط با دکمه LEARN روی برد امکان‌پذیر است.',
        ),
        NumberSettingCard(
          title: 'حذف ریموت از راه دور',
          icon: Icons.delete_outline_rounded,
          label: 'شماره ریموت',
          min: 1,
          max: Gsa212Commands.remoteCount,
          command: (s, v) => s.commands.deleteRemote(v),
        ),
        const SectionCard(
          title: 'راهنمای دکمه‌های ریموت',
          icon: Icons.settings_remote_outlined,
          child: Column(
            children: [
              _RemoteHint(icon: Icons.lock_rounded, text: 'فعال (ARM) – همه زون‌ها فعال'),
              _RemoteHint(icon: Icons.lock_open_rounded, text: 'غیرفعال (DISARM) – همه زون‌ها غیرفعال'),
              _RemoteHint(
                icon: Icons.notifications_active_outlined,
                text: 'درب‌بازکن در حالت غیرفعال، آژیر اضطراری در حالت فعال',
              ),
              _RemoteHint(icon: Icons.bolt_rounded, text: 'نیمه فعال (PARTSET) – زون ۲، ۳ و ۴ فعال'),
            ],
          ),
        ),
      ],
    );
  }
}

class _RemoteHint extends StatelessWidget {
  const _RemoteHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconBadge(icon: icon, size: 32),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ============================================================ Phone line (! ? %)

class PhoneLinePage extends StatelessWidget {
  const PhoneLinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'خط تلفن ثابت',
      children: [
        ToggleSettingCard(
          title: 'نوع شماره‌گیری',
          icon: Icons.dialpad_rounded,
          configKey: ConfigKeys.dialPulse,
          onLabel: 'پالس',
          offLabel: 'تن',
          description: 'بسته به سیستم مخابراتی منطقه انتخاب کنید. پیش‌فرض: تن.',
          command: (s, v) => s.commands.dialMode(pulse: v),
        ),
        NumberSettingCard(
          title: 'تعداد بوق تلفن',
          icon: Icons.ring_volume_outlined,
          label: 'تعداد بوق',
          min: 1,
          max: 9,
          configKey: ConfigKeys.ringCount,
          description: 'دستگاه پس از این تعداد بوق به خط تلفن متصل می‌شود.',
          command: (s, v) => s.commands.ringCount(v),
        ),
        ToggleSettingCard(
          title: 'کنترل از طریق خط تلفن',
          icon: Icons.phone_callback_outlined,
          configKey: ConfigKeys.landlineControl,
          onLabel: 'روشن',
          offLabel: 'خاموش',
          description: 'برای عملکرد بهتر از نویزگیر (اسپلیتر) خط استفاده کنید. پیش‌فرض: فعال.',
          command: (s, v) => s.commands.landlineControl(v),
        ),
        const SectionCard(
          title: 'کلیدهای کنترل با تماس',
          icon: Icons.keyboard_alt_outlined,
          child: Text(
            'پس از تماس و وارد کردن رمز: ۱ تا ۴ کنترل خروجی‌ها • ۵ فعال • ۶ غیرفعال • ۷ نیمه فعال • ۸ فعال بی‌صدا • ۹ استراق سمع',
            style: TextStyle(fontSize: 13, height: 1.9, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ============================================================ Partitions (W S X V U Y R +)

class PartitionsPage extends StatelessWidget {
  const PartitionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'پارتیشن‌بندی',
      children: [
        ToggleSettingCard(
          title: '۱. حالت پارتیشن‌بندی',
          icon: Icons.account_tree_outlined,
          configKey: ConfigKeys.partitionMode,
          description: 'پیش از تعریف رمزهای قسمت‌ها، حالت پارتیشن‌بندی را فعال کنید. در این حالت هر خروجی با رمز مربوط به خود کنترل می‌شود.',
          command: (s, v) => s.commands.partitionMode(v),
        ),
        _ZoneAccessCard(
          title: '۲. دسترسی رمزهای کنترلی',
          icon: Icons.key_outlined,
          numberLabel: 'شماره رمز (قسمت)',
          numbers: const [1, 2, 3, 4],
          description: 'مشخص کنید هر رمز کنترلی (قسمت) کدام زون‌ها را کنترل کند.',
          build: (c, n, z) => c.passwordPartition(part: n, zones: z),
        ),
        const _PartPasswordCard(),
        const _PartControlCard(),
        _ZoneAccessCard(
          title: '۵. پارتیشن ریموت‌ها',
          icon: Icons.settings_remote_outlined,
          numberLabel: 'شماره ریموت',
          numbers: [for (var i = 1; i <= Gsa212Commands.remoteCount; i++) i],
          description: 'مشخص کنید هر ریموت کدام زون‌ها را کنترل کند.',
          build: (c, n, z) => c.remotePartition(remote: n, zones: z),
        ),
        _ZoneAccessCard(
          title: '۶. پارتیشن حافظه‌های تلفن',
          icon: Icons.contacts_outlined,
          numberLabel: 'شماره حافظه',
          numbers: [for (var i = 1; i <= Gsa212Commands.memoryCount; i++) i],
          description: 'با تحریک زون‌های انتخابی، فقط به این حافظه پیامک یا تماس انجام می‌شود.',
          build: (c, n, z) => c.memoryPartition(memory: n, zones: z),
        ),
        const _OutputProgramCard(),
        const _NotificationCard(),
      ],
    );
  }
}

class _ZoneAccessCard extends StatefulWidget {
  const _ZoneAccessCard({
    required this.title,
    required this.icon,
    required this.numberLabel,
    required this.numbers,
    required this.build,
    this.description,
  });

  final String title;
  final IconData icon;
  final String numberLabel;
  final List<int> numbers;
  final String? description;
  final DeviceCommand Function(Gsa212Commands c, int number, ZoneMask zones) build;

  @override
  State<_ZoneAccessCard> createState() => _ZoneAccessCardState();
}

class _ZoneAccessCardState extends State<_ZoneAccessCard> {
  late int _number = widget.numbers.first;
  ZoneMask _zones = ZoneMask.none;

  @override
  Widget build(BuildContext context) {
    final many = widget.numbers.length > 6;
    return SectionCard(
      title: widget.title,
      icon: widget.icon,
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
          if (many)
            DropdownButtonFormField<int>(
              initialValue: _number,
              decoration: InputDecoration(labelText: widget.numberLabel),
              items: [for (final n in widget.numbers) DropdownMenuItem(value: n, child: Text(_fa(n)))],
              onChanged: (v) => setState(() => _number = v ?? _number),
            )
          else
            NumberChoice(
              label: widget.numberLabel,
              options: widget.numbers,
              value: _number,
              onChanged: (v) => setState(() => _number = v),
            ),
          const SizedBox(height: 14),
          ZoneSelector(value: _zones, onChanged: (v) => setState(() => _zones = v)),
          const SizedBox(height: 16),
          SendButton(
            onPressed: () =>
                sendFromSettings(context, widget.build(context.read<DeviceCubit>().state.commands, _number, _zones)),
          ),
        ],
      ),
    );
  }
}

class _PartPasswordCard extends StatefulWidget {
  const _PartPasswordCard();

  @override
  State<_PartPasswordCard> createState() => _PartPasswordCardState();
}

class _PartPasswordCardState extends State<_PartPasswordCard> {
  final _formKey = GlobalKey<FormState>();
  int _part = 1;
  final _old = TextEditingController(text: '0000');
  final _next = TextEditingController();

  @override
  void dispose() {
    _old.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '۳. تغییر رمز هر قسمت',
      icon: Icons.lock_reset_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'رمز پیش‌فرض همه قسمت‌ها ۰۰۰۰ است.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            NumberChoice(
              label: 'قسمت',
              options: const [1, 2, 3, 4],
              value: _part,
              onChanged: (v) => setState(() => _part = v),
            ),
            const SizedBox(height: 14),
            PasswordField(controller: _old, label: 'رمز فعلی قسمت'),
            const SizedBox(height: 12),
            PasswordField(controller: _next, label: 'رمز جدید قسمت'),
            const SizedBox(height: 16),
            SendButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                sendFromSettings(
                  context,
                  context.read<DeviceCubit>().state.commands.partPasswordChange(
                    part: _part,
                    oldPassword: _old.text,
                    newPassword: _next.text,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PartControlCard extends StatefulWidget {
  const _PartControlCard();

  @override
  State<_PartControlCard> createState() => _PartControlCardState();
}

class _PartControlCardState extends State<_PartControlCard> {
  final _formKey = GlobalKey<FormState>();
  int _part = 1;
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _send(bool arm) {
    if (!_formKey.currentState!.validate()) return;
    sendFromSettings(
      context,
      context.read<DeviceCubit>().state.commands.partControl(part: _part, arm: arm, partPassword: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '۴. فعال/غیرفعال کردن هر قسمت',
      icon: Icons.shield_outlined,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NumberChoice(
              label: 'قسمت',
              options: const [1, 2, 3, 4],
              value: _part,
              onChanged: (v) => setState(() => _part = v),
            ),
            const SizedBox(height: 14),
            PasswordField(controller: _password, label: 'رمز کنترلی قسمت'),
            const SizedBox(height: 16),
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
    );
  }
}

class _OutputProgramCard extends StatefulWidget {
  const _OutputProgramCard();

  @override
  State<_OutputProgramCard> createState() => _OutputProgramCardState();
}

class _OutputProgramCardState extends State<_OutputProgramCard> {
  final _formKey = GlobalKey<FormState>();
  int _output = 1;
  ZoneMask _zones = ZoneMask.none;
  final _seconds = TextEditingController(text: '0');

  @override
  void dispose() {
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '۷. برنامه‌ریزی خروجی‌ها',
      icon: Icons.electrical_services_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'هنگام آژیر زون‌های انتخابی، خروجی به مدت مشخص فعال شود. زمان ۰ یعنی دائم.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
            ),
            const SizedBox(height: 12),
            NumberChoice(
              label: 'خروجی',
              options: const [1, 2, 3, 4],
              value: _output,
              onChanged: (v) => setState(() => _output = v),
            ),
            const SizedBox(height: 14),
            ZoneSelector(value: _zones, onChanged: (v) => setState(() => _zones = v), label: 'زون‌های تحریک‌کننده'),
            const SizedBox(height: 14),
            TextFormField(
              controller: _seconds,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              maxLength: 3,
              inputFormatters: const [LatinDigitsFormatter()],
              decoration: const InputDecoration(
                labelText: 'مدت فعال بودن',
                suffixText: 'ثانیه',
                helperText: '۰ تا ۲۵۵ ثانیه (۰ = دائم)',
                counterText: '',
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n > 255 ? 'عددی بین ۰ تا ۲۵۵ وارد کنید' : null;
              },
            ),
            const SizedBox(height: 16),
            SendButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                sendFromSettings(
                  context,
                  context.read<DeviceCubit>().state.commands.outputProgram(
                    output: _output,
                    zones: _zones,
                    seconds: int.parse(_seconds.text),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  const _NotificationCard();

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  int _zone = 1;
  bool _siren = true;
  bool _sms = true;
  bool _call = true;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  void _load(int zone) {
    final saved = context.read<DeviceCubit>().state.config[ConfigKeys.notify(zone)];
    setState(() {
      _zone = zone;
      if (saved is Map) {
        _siren = saved['siren'] as bool? ?? true;
        _sms = saved['sms'] as bool? ?? true;
        _call = saved['call'] as bool? ?? true;
      } else {
        _siren = _sms = _call = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '۸. پارتیشن‌بندی اطلاع‌رسانی',
      icon: Icons.notifications_active_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'مشخص کنید هنگام تحریک هر زون آژیر، پیامک و تماس انجام شود یا خیر.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
          ),
          const SizedBox(height: 12),
          NumberChoice(label: 'زون', options: const [1, 2, 3, 4], value: _zone, onChanged: _load),
          const SizedBox(height: 8),
          LabeledSwitch(
            label: 'آژیر',
            icon: Icons.campaign_outlined,
            value: _siren,
            onChanged: (v) => setState(() => _siren = v),
          ),
          LabeledSwitch(
            label: 'پیامک',
            icon: Icons.sms_outlined,
            value: _sms,
            onChanged: (v) => setState(() => _sms = v),
          ),
          LabeledSwitch(
            label: 'تماس',
            icon: Icons.call_outlined,
            value: _call,
            onChanged: (v) => setState(() => _call = v),
          ),
          const SizedBox(height: 12),
          SendButton(
            onPressed: () => sendFromSettings(
              context,
              context.read<DeviceCubit>().state.commands.notificationPartition(
                zone: _zone,
                siren: _siren,
                sms: _sms,
                call: _call,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
