import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/network/api_client.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/biometric_auth_coordinator.dart';
import 'features/custody/data/custody_repository.dart';
import 'features/dashboard/data/dashboard_repository.dart';
import 'features/crm/data/crm_repository.dart';
import 'features/meetings/data/meetings_repository.dart';
import 'features/extracts/data/extract_repository.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/notifications/application/push_notification_service.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/scm/data/scm_repository.dart';
import 'features/treasury/data/treasury_repository.dart';
import 'features/users/data/users_repository.dart';
import 'features/workflow/data/workflow_repository.dart';
import 'features/workspace/application/workspace_controller.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final client = await ApiClient.create();
    final preferences = await SharedPreferences.getInstance();
    final notificationRepository = NotificationRepository(client);
    final pushNotifications = PushNotificationService(
      repository: notificationRepository,
    );
    final repository = AuthRepository(client: client, prefs: preferences);
    final controller = AuthController(
      repository,
      biometrics: BiometricAuthCoordinator(client: client, prefs: preferences),
    );
    final workspace = WorkspaceController(
      repository: WorkspaceRepository(client),
      custody: CustodyRepository(client),
      settings: SettingsRepository(client),
      extracts: ExtractRepository(client),
      notifications: notificationRepository,
      treasury: TreasuryRepository(client),
      scm: ScmRepository(client),
      crm: CrmRepository(client),
      meetings: MeetingsRepository(client),
      workflow: WorkflowRepository(client),
      users: UsersRepository(client),
      dashboard: DashboardRepository(client),
    );
    controller.onSessionEnded = () {
      workspace.reset();
      pushNotifications.clearLocalUser();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    };
    workspace.addListener(() {
      client.operationScope = controller.user?.id;
      client.companyId = workspace.context?.activeCompanyId;
    });
    client.onSessionExpired = controller.expireSession;
    runApp(
      FundFlowApp(
        authController: controller,
        workspaceController: workspace,
        pushNotifications: pushNotifications,
      ),
    );
    await controller.initialize();
    await pushNotifications.start();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'FundFlow bootstrap',
      ),
    );
    runApp(const _BootstrapFailureApp());
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Color(0xFF173E36),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_ethernet,
                      color: Colors.white,
                      size: 42,
                    ),
                    SizedBox(height: 18),
                    Text(
                      'تعذر تشغيل التطبيق بسبب إعداد الاتصال',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'حدّث التطبيق أو تواصل مع مسؤول النظام.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
