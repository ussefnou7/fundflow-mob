import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/app/app.dart';
import 'package:fundflow_mob/features/auth/application/auth_controller.dart';
import 'package:fundflow_mob/features/auth/domain/auth_gateway.dart';
import 'package:fundflow_mob/features/auth/domain/auth_user.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/custody/data/custody_repository.dart';
import 'package:fundflow_mob/features/workspace/application/workspace_controller.dart';
import 'package:fundflow_mob/features/workspace/domain/workspace_context.dart';

void main() {
  testWidgets('login screen visual', (tester) async {
    await _loadFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = AuthController(_LoggedOutGateway());
    await controller.initialize();
    final client = ApiClient(dio: Dio(), cookieJar: CookieJar());
    final workspace = WorkspaceController.seeded(
      custody: CustodyRepository(client),
      context: const WorkspaceContext(
        theme: FundFlowBrand.evergreen,
        companyName: 'شركة الاختبار',
        permissions: {},
      ),
    );
    await tester.pumpWidget(
      FundFlowApp(authController: controller, workspaceController: workspace),
    );
    await tester.pumpAndSettle();
    // Asset images decode off the test clock; wait so the wordmark is drawn.
    await tester.runAsync(() async {
      final image = tester.widget<Image>(find.byType(Image)).image;
      await precacheImage(image, tester.element(find.byType(Image)));
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/login_390x844.png'),
    );
  });
}

Future<void> _loadFonts() async {
  final cairo = FontLoader('Cairo')
    ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(
      rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
    );
  await Future.wait([cairo.load(), lucide.load()]);
}

class _LoggedOutGateway implements AuthGateway {
  @override
  String get savedTenant => 'SHG';

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<AuthUser> login({
    required String tenant,
    required String username,
    required String password,
    String? code,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}
}
