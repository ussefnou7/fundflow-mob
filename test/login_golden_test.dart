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
    addTearDown(tester.view.resetViewInsets);

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
      final imageFinder = find.byType(Image).first;
      final image = tester.widget<Image>(imageFinder).image;
      await precacheImage(image, tester.element(imageFinder));
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/login_390x844.png'),
    );

    final password = find.byType(TextFormField).at(2);
    await tester.tap(password);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(tester.getRect(password).bottom, lessThanOrEqualTo(524));
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
