import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injection.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_logo.dart';
import 'core/widgets/gradient_background.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/lock_page.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/devices/domain/entities/device_message.dart';
import 'features/devices/domain/usecases/incoming_sms_coordinator.dart';
import 'features/devices/presentation/cubit/devices_cubit.dart';
import 'features/devices/presentation/pages/home_page.dart';
import 'features/devices/presentation/widgets/send_feedback.dart';

class FiveStarApp extends StatefulWidget {
  const FiveStarApp({super.key});

  @override
  State<FiveStarApp> createState() => _FiveStarAppState();
}

class _FiveStarAppState extends State<FiveStarApp> with WidgetsBindingObserver {
  static const _autoLockAfter = Duration(minutes: 3);

  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = rootMessengerKey;
  late final AuthBloc _auth = AuthBloc(repository: sl())..add(const AuthStarted());
  late final DevicesCubit _devices = DevicesCubit(sl())..load();
  late final IncomingSmsCoordinator _incoming = sl();
  StreamSubscription<IncomingReply>? _replies;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _replies = _incoming.replies.listen(_showReply);
    _incoming.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _replies?.cancel();
    _incoming.dispose();
    _auth.close();
    _devices.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _pausedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final pausedAt = _pausedAt;
        _pausedAt = null;
        if (pausedAt != null && DateTime.now().difference(pausedAt) > _autoLockAfter) {
          _auth.add(const AuthLockRequested());
        }
        _incoming.drain();
      default:
        break;
    }
  }

  void _showReply(IncomingReply reply) {
    final alert = reply.response.severity == MessageSeverity.alert;
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: alert ? AppColors.danger : AppColors.primaryDark,
          content: Row(
            children: [
              Icon(alert ? Icons.warning_amber_rounded : Icons.sms_outlined, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('${reply.device.name}: ${reply.response.title}')),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _auth),
        BlocProvider.value(value: _devices),
      ],
      child: MaterialApp(
        title: 'FiveStar',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        theme: AppTheme.light,
        locale: const Locale('fa', 'IR'),
        supportedLocales: const [Locale('fa', 'IR'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (prev, next) => prev.status != next.status,
          listener: (context, state) {
            if (state.status == AuthStatus.unregistered) {
              _navigatorKey.currentState?.popUntil((route) => route.isFirst);
            }
          },
          buildWhen: (prev, next) => prev.status != next.status,
          builder: (context, state) => Stack(
            children: [
              ?child,
              if (state.status == AuthStatus.locked)
                Positioned.fill(
                  child: Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const LockPage())),
                ),
            ],
          ),
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, next) => prev.status != next.status,
      builder: (context, state) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: switch (state.status) {
          AuthStatus.initial => const _Splash(),
          AuthStatus.unregistered => const WelcomePage(),
          AuthStatus.locked || AuthStatus.unlocked => const HomePage(),
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GradientBackground(child: Center(child: AppLogo(size: 130))),
    );
  }
}
