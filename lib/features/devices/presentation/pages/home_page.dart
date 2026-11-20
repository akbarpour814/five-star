import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../auth/presentation/pages/app_settings_page.dart';
import '../../domain/entities/device_message.dart';
import '../cubit/devices_cubit.dart';
import '../widgets/status_visuals.dart';
import 'device_page.dart';
import 'register_device_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _addDevice(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterDevicePage(withAppSecurity: false)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _addDevice(context),
        icon: const Icon(Icons.add),
        label: const Text('افزودن دستگاه', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: BlocBuilder<DevicesCubit, DevicesState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _HomeHeader(count: state.items.length)),
              if (state.loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (state.items.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _EmptyState(onAdd: () => _addDevice(context)))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _DeviceCard(item: state.items[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GradientHeader(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 26),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Image.asset('assets/images/logo.png'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'دستگاه‌های من',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0 ? 'هنوز دستگاهی ثبت نشده' : '${TextNormalizer.toPersianDigits(count)} دستگاه ثبت شده',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تنظیمات برنامه',
                color: Colors.white,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppSettingsPage())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.item});

  final DeviceOverview item;

  @override
  Widget build(BuildContext context) {
    final status = item.status;
    final last = item.lastMessage;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DevicePage(device: item.device))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 22, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.security_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.device.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.device.model} • ${item.device.simNumber}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ArmStateChip(status.arm),
                  if (status.powerConnected != null)
                    _MiniChip(
                      icon: status.powerConnected! ? Icons.power_rounded : Icons.power_off_rounded,
                      label: status.powerConnected! ? 'برق وصل' : 'برق قطع',
                      color: status.powerConnected! ? AppColors.success : AppColors.danger,
                    ),
                  if (status.signal != null)
                    _MiniChip(
                      icon: Icons.signal_cellular_alt_rounded,
                      label: 'آنتن ${status.signal!.label}',
                      color: AppColors.primary,
                    ),
                ],
              ),
              if (last != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      last.isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded,
                      size: 16,
                      color: last.severity == MessageSeverity.alert ? AppColors.danger : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        last.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: last.severity == MessageSeverity.alert ? AppColors.danger : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      AppDateFormat.relative(last.at),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(color: AppColors.ice, borderRadius: BorderRadius.circular(36)),
            child: const Icon(Icons.router_outlined, size: 54, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text('دستگاهی ثبت نشده است', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'برای کنترل دزدگیر، دستگاه GSA-212 خود را اضافه کنید',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('افزودن دستگاه')),
        ],
      ),
    );
  }
}
