import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/notifications/application/push_notification_service.dart';
import '../features/workspace/application/workspace_controller.dart';
import '../features/workspace/presentation/workspace_shell.dart';

class FundFlowApp extends StatefulWidget {
  const FundFlowApp({
    super.key,
    required this.authController,
    required this.workspaceController,
    this.pushNotifications,
  });

  final AuthController authController;
  final WorkspaceController workspaceController;
  final PushNotificationService? pushNotifications;

  @override
  State<FundFlowApp> createState() => _FundFlowAppState();
}

class _FundFlowAppState extends State<FundFlowApp> with WidgetsBindingObserver {
  AuthController get authController => widget.authController;
  WorkspaceController get workspaceController => widget.workspaceController;
  PushNotificationService? get pushNotifications => widget.pushNotifications;
  DateTime? _backgroundAt;
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final since = _backgroundAt;
      _backgroundAt = null;
      if (since != null &&
          DateTime.now().difference(since) >= const Duration(minutes: 2) &&
          authController.status == AuthStatus.authenticated) {
        authController.logout();
      }
      setState(() => _obscured = false);
    } else {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        _backgroundAt ??= DateTime.now();
      }
      setState(() => _obscured = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([authController, workspaceController]),
      builder: (context, _) {
        return MaterialApp(
          key: ValueKey(
            authController.status == AuthStatus.authenticated
                ? 'user:${authController.user?.id}'
                : authController.status.name,
          ),
          debugShowCheckedModeBanner: false,
          title: 'Monetizer',
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (_obscured)
                  const Positioned.fill(
                    child: ColoredBox(color: AppColors.petrolDark),
                  ),
              ],
            ),
          ),
          theme: AppTheme.light(
            workspaceController.context?.theme ?? FundFlowBrand.evergreen,
          ),
          home: Builder(
            builder: (context) {
              return switch (authController.status) {
                AuthStatus.booting => const _BootScreen(),
                AuthStatus.unauthenticated => LoginScreen(
                  controller: authController,
                ),
                AuthStatus.authenticated => WorkspaceShell(
                  auth: authController,
                  workspace: workspaceController,
                  pushNotifications: pushNotifications,
                ),
                AuthStatus.failed => _BootErrorScreen(
                  controller: authController,
                ),
              };
            },
          ),
        );
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.petrolDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 132,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                child: Image(
                  image: AssetImage('assets/images/monetizer-logo.png'),
                ),
              ),
            ),
            SizedBox(height: 26),
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 18),
            Text(
              'جارٍ تحميل Monetizer…',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.petrolDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.errorMessage ?? 'تعذر الاتصال بالخادم',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: controller.initialize,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
