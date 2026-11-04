import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/app/app.dart';
import 'package:fundflow_mob/features/auth/application/auth_controller.dart';
import 'package:fundflow_mob/features/auth/domain/auth_gateway.dart';
import 'package:fundflow_mob/features/auth/domain/auth_user.dart';
import 'package:fundflow_mob/features/custody/data/custody_repository.dart';
import 'package:fundflow_mob/features/workspace/application/workspace_controller.dart';
import 'package:fundflow_mob/features/workspace/domain/workspace_context.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';

void main() {
  testWidgets('shows the Arabic login form and submits credentials', (
    tester,
  ) async {
    final gateway = _FakeAuthGateway();
    final controller = AuthController(gateway);
    await controller.initialize();

    await tester.pumpWidget(
      FundFlowApp(
        authController: controller,
        workspaceController: _workspace(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsNWidgets(2));
    expect(find.text('كود العميل'), findsOneWidget);
    expect(find.text('اسم الدخول'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);

    expect(
      Directionality.of(tester.element(find.byType(TextFormField).first)),
      TextDirection.rtl,
    );
    final tenantField = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).first,
        matching: find.byType(EditableText),
      ),
    );
    expect(tenantField.textAlign, TextAlign.right);
    expect(tenantField.textDirection, TextDirection.ltr);

    final fields = find.byType(TextFormField);
    final passwordEditable = find.descendant(
      of: fields.at(2),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(passwordEditable).obscureText, isTrue);
    await tester.tap(find.byTooltip('إظهار كلمة المرور'));
    await tester.pump();
    expect(tester.widget<EditableText>(passwordEditable).obscureText, isFalse);
    expect(find.byTooltip('إخفاء كلمة المرور'), findsOneWidget);

    await tester.enterText(fields.at(0), 'shg');
    await tester.enterText(fields.at(1), 'ahmed');
    await tester.enterText(fields.at(2), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(gateway.lastTenant, 'shg');
    expect(gateway.lastUsername, 'ahmed');
    expect(controller.status, AuthStatus.authenticated);
  });
}

WorkspaceController _workspace() {
  final client = ApiClient(dio: Dio(), cookieJar: CookieJar());
  return WorkspaceController.seeded(
    custody: CustodyRepository(client),
    context: const WorkspaceContext(
      theme: FundFlowBrand.evergreen,
      companyName: 'شركة الاختبار',
      permissions: {},
    ),
  );
}

class _FakeAuthGateway implements AuthGateway {
  String? lastTenant;
  String? lastUsername;

  @override
  String get savedTenant => '';

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<AuthUser> login({
    required String tenant,
    required String username,
    required String password,
    String? code,
  }) async {
    lastTenant = tenant;
    lastUsername = username;
    return const AuthUser(
      id: 'user-1',
      name: 'أحمد',
      username: 'ahmed',
      platformAdmin: false,
    );
  }

  @override
  Future<void> logout() async {}
}
