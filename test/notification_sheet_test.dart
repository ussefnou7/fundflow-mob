import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/notifications/data/notification_repository.dart';
import 'package:fundflow_mob/features/notifications/domain/notification_models.dart';
import 'package:fundflow_mob/features/notifications/presentation/notification_sheet.dart';

void main() {
  testWidgets('shows and reads the notification inbox', (tester) async {
    final repository = _FakeNotificationRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showGeneralDialog<AppNotification>(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'إغلاق',
                    pageBuilder: (_, _, _) =>
                        NotificationSheet(repository: repository),
                  ),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.text('طلب عهدة جديد'), findsOneWidget);
    expect(find.text('طلب عهدة من أحمد'), findsOneWidget);

    await tester.tap(find.text('طلب عهدة جديد'));
    await tester.pumpAndSettle();
    expect(repository.readId, 'notice-1');
  });
}

class _FakeNotificationRepository extends NotificationRepository {
  _FakeNotificationRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  String? readId;

  @override
  Future<NotificationInbox> inbox({int page = 0, int size = 20}) async =>
      NotificationInbox(
        items: const [
          AppNotification(
            companyId: 'company-1',
            companyName: 'سكاي هاوس',
            id: 'notice-1',
            kind: 'CUSTODY_REQUESTED',
            message: 'طلب عهدة من أحمد',
            dateMismatch: false,
            createdAt: '2026-10-26T12:00:00+02:00',
            custodyRequestId: 'request-1',
          ),
        ],
        total: 1,
        unreadCount: 1,
        page: page,
        size: size,
      );

  @override
  Future<void> read(String id) async {
    readId = id;
  }
}
