import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/platform/sms_gateway.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../gsa212/presentation/pages/settings_pages.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/device_message.dart';
import '../../domain/entities/device_status.dart';
import '../cubit/device_cubit.dart';
import '../widgets/cooldown_banner.dart';
import '../widgets/rename_output_dialog.dart';
import '../widgets/send_feedback.dart';
import '../widgets/status_visuals.dart';
import 'edit_device_page.dart';
import 'part_control_tab.dart';
import 'paste_response_page.dart';
import 'sim_selection_page.dart';

void pushWithDevice(BuildContext context, Widget page) {
  final cubit = context.read<DeviceCubit>();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(value: cubit, child: page),
    ),
  );
}

class DevicePage extends StatelessWidget {
  const DevicePage({super.key, required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DeviceCubit(device: device, repository: sl(), sendCommand: sl(), processReply: sl())..load(),
      child: const _DeviceView(),
    );
  }
}

class _DeviceView extends StatelessWidget {
  const _DeviceView();

  @override
  Widget build(BuildContext context) {
    final autoReceive = sl<SmsGateway>().receivesAutomatically;
    return BlocListener<DeviceCubit, DeviceState>(
      listenWhen: (prev, next) => !prev.deleted && next.deleted,
      listener: (context, _) => Navigator.of(context).popUntil((r) => r.isFirst),
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          floatingActionButton: autoReceive
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'paste',
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  onPressed: () => pushWithDevice(context, const PasteResponsePage()),
                  label: const FabLabel(text: 'ثبت پاسخ دستگاه', icon: Icons.content_paste_go_rounded),
                ),
          // Header and tabs stay fixed; scrolling them away pushed the tabs under the status bar.
          body: const Column(
            children: [
              _DeviceHeader(),
              CooldownBanner(),
              Expanded(child: TabBarView(children: [_ControlTab(), PartControlTab(), _SettingsTab(), _MessagesTab()])),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader();

  @override
  Widget build(BuildContext context) {
    final autoReceive = sl<SmsGateway>().receivesAutomatically;
    return BlocBuilder<DeviceCubit, DeviceState>(
      builder: (context, state) {
        final status = state.status;
        return GradientHeader(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      const BackButton(color: Colors.white),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              state.device.name,
                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${state.device.model} • ${state.device.simNumber}',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        iconColor: Colors.white,
                        onSelected: (value) => switch (value) {
                          'paste' => pushWithDevice(context, const PasteResponsePage()),
                          _ => pushWithDevice(context, const EditDevicePage()),
                        },
                        itemBuilder: (_) => [
                          if (autoReceive)
                            const PopupMenuItem(
                              value: 'paste',
                              child: ListTile(
                                leading: Icon(Icons.content_paste_go_rounded),
                                title: Text('ثبت دستی پاسخ'),
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('ویرایش دستگاه')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      _StatusTile(
                        icon: status.arm.icon,
                        label: 'دزدگیر',
                        value: status.arm.label,
                        highlight: status.arm != ArmState.unknown,
                      ),
                      _StatusTile(
                        icon: status.powerConnected == false ? Icons.power_off_rounded : Icons.power_rounded,
                        label: 'برق',
                        value: switch (status.powerConnected) {
                          null => '—',
                          true => 'وصل',
                          false => 'قطع',
                        },
                        alert: status.powerConnected == false,
                      ),
                      _StatusTile(
                        icon: status.batteryOk == false ? Icons.battery_alert_rounded : Icons.battery_full_rounded,
                        label: 'باتری',
                        value: switch (status.batteryOk) {
                          null => '—',
                          true => 'سالم',
                          false => 'ضعیف',
                        },
                        alert: status.batteryOk == false,
                      ),
                      _StatusTile(
                        iconWidget: SignalBars(level: status.signal),
                        label: 'آنتن',
                        value: status.antenna == null
                            ? '—'
                            : '${status.signal!.label} (${TextNormalizer.toPersianDigits(status.antenna!)})',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    status.updatedAt == null
                        ? 'برای دریافت وضعیت، «استعلام وضعیت» را ارسال کنید'
                        : 'آخرین به‌روزرسانی: ${AppDateFormat.relative(status.updatedAt!)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'کنترل', icon: Icon(Icons.gamepad_outlined, size: 20)),
                    Tab(text: 'کنترل پارت', icon: Icon(Icons.account_tree_outlined, size: 20)),
                    Tab(text: 'تنظیمات', icon: Icon(Icons.tune_rounded, size: 20)),
                    Tab(text: 'پیام‌ها', icon: Icon(Icons.forum_outlined, size: 20)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.value,
    this.alert = false,
    this.highlight = false,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final String value;
  final bool alert;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: alert
              ? AppColors.danger.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: highlight ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 24,
              child: Center(child: iconWidget ?? Icon(icon, color: Colors.white, size: 22)),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Control tab

class _ControlTab extends StatelessWidget {
  const _ControlTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceCubit, DeviceState>(
      builder: (context, state) {
        final cubit = context.read<DeviceCubit>();
        final c = state.commands;
        void send(command) => sendDeviceCommand(context, cubit, command);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (state.usesDefaultPassword) ...[
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => pushWithDevice(context, const DevicePasswordPage()),
                child: const InfoBanner(
                  icon: Icons.gpp_maybe_outlined,
                  color: Color(0xFFB7791F),
                  text: 'رمز دستگاه هنوز پیش‌فرض (۰۰۰۰) است. برای امنیت بیشتر آن را تغییر دهید (اختیاری).',
                ),
              ),
              const SizedBox(height: 14),
            ],
            SectionCard(
              title: 'وضعیت دزدگیر',
              icon: Icons.shield_outlined,
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _ArmButton(
                    state: ArmState.armed,
                    title: 'فعال',
                    current: state.status.arm,
                    onTap: () => send(c.arm()),
                  ),
                  _ArmButton(
                    state: ArmState.disarmed,
                    title: 'غیرفعال',
                    current: state.status.arm,
                    onTap: () => send(c.disarm()),
                  ),
                  _ArmButton(
                    state: ArmState.partset,
                    title: 'نیمه فعال',
                    current: state.status.arm,
                    onTap: () => send(c.partSet()),
                  ),
                  _ArmButton(
                    state: ArmState.silent,
                    title: 'فعال بی‌صدا',
                    current: state.status.arm,
                    onTap: () => send(c.silentArm()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'خروجی‌ها',
              icon: Icons.electrical_services_rounded,
              child: Column(
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    _OutputTile(
                      output: i,
                      name: state.device.outputName(i),
                      custom: state.device.hasCustomOutputName(i),
                      on: state.status.outputs[i - 1],
                      onRename: () => _renameOutput(context, state.device, i),
                      onToggle: () => send(c.outputToggle(i)),
                      onPulse: () => send(c.outputMomentary(i)),
                    ),
                    if (i < 4) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'دستورات سریع',
              icon: Icons.bolt_rounded,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  _QuickAction(
                    icon: Icons.door_front_door_outlined,
                    label: 'درب‌بازکن',
                    onTap: () => send(c.openDoor()),
                  ),
                  _QuickAction(icon: Icons.fact_check_outlined, label: 'استعلام وضعیت', onTap: () => send(c.status())),
                  _QuickAction(
                    icon: Icons.signal_cellular_alt_rounded,
                    label: 'قدرت آنتن',
                    onTap: () => send(c.antenna()),
                  ),
                  _QuickAction(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'استعلام شارژ',
                    onTap: () => send(c.simBalance()),
                  ),
                  _QuickAction(icon: Icons.contacts_outlined, label: 'استعلام حافظه', onTap: () => send(c.memories())),
                  _QuickAction(
                    icon: Icons.phone_disabled_outlined,
                    label: 'توقف شماره‌گیری',
                    onTap: () => send(c.stopDialing()),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArmButton extends StatelessWidget {
  const _ArmButton({required this.state, required this.title, required this.current, required this.onTap});

  final ArmState state;
  final String title;
  final ArmState current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = state == current;
    return BlocSelector<DeviceCubit, DeviceState, bool>(
      selector: (s) => s.canSend,
      builder: (context, canSend) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: active ? state.color : state.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (active)
              BoxShadow(color: state.color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canSend ? onTap : () => sendDeviceCommandBlocked(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: active ? Colors.white : state.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(state.icon, color: active ? Colors.white : state.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void sendDeviceCommandBlocked(BuildContext context) {
  final left = context.read<DeviceCubit>().state.cooldown;
  showAppSnack(context, 'تا ارسال بعدی ${AppDateFormat.countdown(left)} صبر کنید', error: true);
}

Future<void> _renameOutput(BuildContext context, Device device, int output) async {
  final cubit = context.read<DeviceCubit>();
  final result = await showRenameOutputDialog(
    context,
    output: output,
    currentName: device.outputName(output),
    customName: device.outputNames[output],
  );
  if (result != null) await cubit.renameOutput(output, result);
}

/// One output: name (any length, wraps to two lines) with rename, live state, then the two actions on their own row.
class _OutputTile extends StatelessWidget {
  const _OutputTile({
    required this.output,
    required this.name,
    required this.custom,
    required this.on,
    required this.onRename,
    required this.onToggle,
    required this.onPulse,
  });

  final int output;
  final String name;
  final bool custom;
  final bool? on;
  final VoidCallback onRename;
  final VoidCallback onToggle;
  final VoidCallback onPulse;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (on) {
      true => (AppColors.success, 'روشن'),
      false => (AppColors.textSecondary, 'خاموش'),
      null => (AppColors.warning, 'نامشخص'),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: on == true ? AppColors.success.withValues(alpha: 0.06) : AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: on == true ? AppColors.success.withValues(alpha: 0.35) : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: on == true ? AppColors.success : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  output == 1 ? Icons.door_sliding_outlined : Icons.power_outlined,
                  color: on == true ? Colors.white : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                label,
                                style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        if (custom)
                          Text(
                            'خروجی ${TextNormalizer.toPersianDigits(output)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تغییر نام',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.08)),
                onPressed: onRename,
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OutputAction(
                  label: switch (on) {
                    true => 'خاموش کردن',
                    false => 'روشن کردن',
                    null => 'روشن / خاموش',
                  },
                  icon: Icons.power_settings_new_rounded,
                  onTap: onToggle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OutputAction(label: 'لحظه‌ای', icon: Icons.flash_on_rounded, onTap: onPulse, outlined: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutputAction extends StatelessWidget {
  const _OutputAction({required this.label, required this.icon, required this.onTap, this.outlined = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DeviceCubit, DeviceState, bool>(
      selector: (s) => s.canSend,
      builder: (context, canSend) {
        final fg = outlined ? AppColors.primary : Colors.white;
        return Opacity(
          opacity: canSend ? 1 : 0.45,
          child: Material(
            color: outlined ? Colors.white : AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: outlined ? const BorderSide(color: AppColors.primary) : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: canSend ? onTap : () => sendDeviceCommandBlocked(context),
              child: SizedBox(
                height: 42,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(icon, size: 17, color: fg),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DeviceCubit, DeviceState, bool>(
      selector: (s) => s.canSend,
      builder: (context, canSend) => Material(
        color: AppColors.ice,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canSend ? onTap : () => sendDeviceCommandBlocked(context),
          child: Opacity(
            opacity: canSend ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.primary, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Settings tab

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final simSlot = context.select<DeviceCubit, int?>((c) => c.state.device.simSlot);
    final groups = <(String, List<(IconData, String, String, Widget)>)>[
      (
        'تنظیمات پایه',
        [
          if (sl<SmsGateway>().supportsSimSelection)
            (
              Icons.sim_card_outlined,
              'سیم‌کارت ارسال دستور',
              simSlot == null ? 'سیم‌کارت پیش‌فرض گوشی' : 'ارسال از سیم ${TextNormalizer.toPersianDigits(simSlot + 1)}',
              const SimSelectionPage(),
            ),
          (Icons.contacts_outlined, 'حافظه‌های تلفن', 'ثبت ۳۰ شماره پیامک و تماس', const PhoneMemoriesPage()),
          (Icons.password_rounded, 'رمز دستگاه', 'تغییر رمز کنترلی ۴ رقمی', const DevicePasswordPage()),
          (Icons.sim_card_outlined, 'سیم‌کارت و شارژ', 'شارژ، USSD و استعلام خودکار', const SimSettingsPage()),
          (Icons.campaign_outlined, 'آژیر و صدا', 'زمان آژیر و حالت تک‌آژیر', const SirenSoundPage()),
        ],
      ),
      (
        'امنیت و گزارش‌ها',
        [
          (
            Icons.verified_user_outlined,
            'سطح امنیت و گزارش‌ها',
            'امنیت، گزارش ریموت، برق و اخطارها',
            const SecurityReportsPage(),
          ),
          (Icons.sensors_rounded, 'تنظیمات زون‌ها', 'NC/NO، دینگ‌دانگ، نوع و تاخیر زون', const ZonesPage()),
          (Icons.settings_remote_outlined, 'ریموت‌ها', 'حذف ریموت از راه دور', const RemotesPage()),
          (Icons.phone_in_talk_outlined, 'خط تلفن ثابت', 'تن/پالس، تعداد بوق، کنترل با تماس', const PhoneLinePage()),
        ],
      ),
      (
        'قابلیت‌های ویژه',
        [
          (
            Icons.account_tree_outlined,
            'پارتیشن‌بندی',
            'پارت‌ها، ریموت‌ها، حافظه‌ها و خروجی‌ها',
            const PartitionsPage(),
          ),
        ],
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(
              group.$1,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary),
            ),
          ),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < group.$2.length; i++) ...[
                  ListTile(
                    leading: IconBadge(icon: group.$2[i].$1),
                    title: Text(group.$2[i].$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    subtitle: Text(group.$2[i].$3, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => pushWithDevice(context, group.$2[i].$4),
                  ),
                  if (i < group.$2.length - 1) const Divider(indent: 72),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Messages tab

class _MessagesTab extends StatelessWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceCubit, DeviceState>(
      buildWhen: (p, n) => p.messages != n.messages,
      builder: (context, state) {
        if (state.messages.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined, size: 56, color: AppColors.sky),
                  SizedBox(height: 12),
                  Text('هنوز پیامی ثبت نشده است', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text(
                    'دستورات ارسالی و پاسخ‌های دستگاه اینجا نمایش داده می‌شوند',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }
        final messages = state.messages.reversed.toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    '${TextNormalizer.toPersianDigits(messages.length)} پیام',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: 'پاک کردن تاریخچه',
                        message: 'تمام پیام‌های این دستگاه از برنامه حذف شود؟',
                        confirmLabel: 'پاک کن',
                        destructive: true,
                      );
                      if (ok && context.mounted) context.read<DeviceCubit>().clearMessages();
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('پاک کردن'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: messages.length,
                itemBuilder: (_, i) => _MessageBubble(message: messages[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final DeviceMessage message;

  @override
  Widget build(BuildContext context) {
    final incoming = message.isIncoming;
    final alert = message.severity == MessageSeverity.alert;
    final bg = incoming ? (alert ? const Color(0xFFFFEBEE) : Colors.white) : AppColors.primary;
    final fg = incoming ? AppColors.textPrimary : Colors.white;
    return Align(
      alignment: incoming ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(18),
              topEnd: const Radius.circular(18),
              bottomStart: Radius.circular(incoming ? 4 : 18),
              bottomEnd: Radius.circular(incoming ? 18 : 4),
            ),
            border: incoming
                ? Border.all(color: alert ? AppColors.danger.withValues(alpha: 0.3) : AppColors.divider)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (alert) ...[
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      message.title,
                      style: TextStyle(
                        color: alert ? AppColors.danger : fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (message.detail != null) ...[
                const SizedBox(height: 2),
                Text(message.detail!, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12.5)),
              ],
              const SizedBox(height: 6),
              incoming
                  ? Text(
                      message.body,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.6),
                    )
                  : CodeChip(message.body, dark: true),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${AppDateFormat.relative(message.at)} • ${AppDateFormat.time(message.at)}',
                  style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
