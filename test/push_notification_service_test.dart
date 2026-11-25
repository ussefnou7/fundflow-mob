import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/features/notifications/application/push_notification_service.dart';
import 'package:fundflow_mob/features/notifications/data/notification_repository.dart';

void main() {
  test(
    'on iOS it waits for the APNs token and retries until FCM registers',
    () async {
      final messaging = _FakeMessaging(apnsAfterCalls: 3, registerFailures: 1);
      final repository = _FakeRepository();
      final service = PushNotificationService(
        repository: repository,
        messaging: messaging,
        isIOS: true,
        retryDelay: Duration.zero,
      );
      await service.initialize();
      service.markReady();

      await service.bindAuthenticatedUser();
      await pumpEventQueue();

      expect(
        messaging.registerCalls,
        2,
        reason: 'the first call fails, the retry succeeds',
      );
      expect(messaging.registerBeforeToken, isFalse);
      expect(repository.uploads, [('fid-123', 'IOS')]);
      expect(messaging.autoInit, isTrue);
      expect(
        service.diagnostics.join('\n'),
        allOf(
          contains('permission: authorized'),
          contains('APNs token ok'),
          contains('FCM register attempt 1 failed'),
          contains('FCM registered'),
          contains('sent to server'),
        ),
      );
    },
  );

  test('Android registers at once, without asking for an APNs token', () async {
    final messaging = _FakeMessaging(
      apnsAfterCalls: 1 << 30,
      registerFailures: 0,
    );
    final repository = _FakeRepository();
    final service = PushNotificationService(
      repository: repository,
      messaging: messaging,
      isIOS: false,
      retryDelay: Duration.zero,
    );
    await service.initialize();
    service.markReady();

    await service.bindAuthenticatedUser();
    await pumpEventQueue();

    expect(messaging.apnsCalls, 0);
    expect(repository.uploads, [('fid-123', 'ANDROID')]);
  });
}

class _FakeRepository extends NotificationRepository {
  _FakeRepository() : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  final uploads = <(String, String)>[];

  @override
  Future<void> registerPush({
    required String firebaseInstallationId,
    required String platform,
  }) async => uploads.add((firebaseInstallationId, platform));
}

class _FakeMessaging implements FirebaseMessaging {
  _FakeMessaging({
    required this.apnsAfterCalls,
    required this.registerFailures,
  });

  /// getAPNSToken returns null until it has been asked this many times.
  final int apnsAfterCalls;
  int registerFailures;
  int apnsCalls = 0;
  int registerCalls = 0;
  bool registerBeforeToken = false;
  final _registered = StreamController<String>.broadcast();

  bool get _hasToken => apnsCalls >= apnsAfterCalls;

  @override
  Stream<String> get onRegistered => _registered.stream;

  @override
  Future<String?> getAPNSToken() async {
    apnsCalls++;
    return _hasToken ? 'apns' : null;
  }

  @override
  Future<void> register({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    registerCalls++;
    if (apnsAfterCalls < 1 << 30 && !_hasToken) registerBeforeToken = true;
    if (registerFailures > 0) {
      registerFailures--;
      throw StateError('APNS token not set');
    }
    _registered.add('fid-123');
  }

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async => const NotificationSettings(
    alert: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.disabled,
    authorizationStatus: AuthorizationStatus.authorized,
    badge: AppleNotificationSetting.enabled,
    carPlay: AppleNotificationSetting.disabled,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    showPreviews: AppleShowPreviewSetting.always,
    timeSensitive: AppleNotificationSetting.disabled,
    criticalAlert: AppleNotificationSetting.disabled,
    sound: AppleNotificationSetting.enabled,
    providesAppNotificationSettings: AppleNotificationSetting.disabled,
  );

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {}

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  bool autoInit = false;

  @override
  Future<void> setAutoInitEnabled(bool enabled) async => autoInit = enabled;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
