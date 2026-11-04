import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';
import '../data/notification_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushEvent {
  const PushEvent({
    required this.kind,
    required this.title,
    required this.message,
    required this.opened,
    this.companyId,
    this.companyName,
    this.notificationId,
  });

  final String kind;
  final String title;
  final String message;
  final bool opened;
  final String? companyId;
  final String? companyName;
  final String? notificationId;
}

class PushNotificationService extends ChangeNotifier {
  PushNotificationService({
    required NotificationRepository repository,
    FirebaseMessaging? messaging,
  }) : _repository = repository,
       _providedMessaging = messaging;

  final NotificationRepository _repository;
  final FirebaseMessaging? _providedMessaging;
  FirebaseMessaging get _messaging =>
      _providedMessaging ?? FirebaseMessaging.instance;
  bool _ready = false;
  int _userGeneration = 0;
  StreamSubscription<String>? _registrationSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _registrationId;
  PushEvent? _event;
  bool _authenticated = false;
  bool _initialized = false;

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<PushNotificationService?> create(
    NotificationRepository repository,
  ) async {
    if (!supported) return null;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final service = PushNotificationService(repository: repository);
      await service.initialize();
      return service;
    } catch (error, stackTrace) {
      // Push setup is optional and must never prevent the app from starting.
      debugPrint('Firebase push initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> start() async {
    if (!supported) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await initialize();
      _ready = true;
      if (_authenticated) await bindAuthenticatedUser();
    } catch (_) {
      // Inbox remains available without push support.
    }
  }

  void clearLocalUser() {
    _userGeneration++;
    _authenticated = false;
    _event = null;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _registrationSubscription = _messaging.onRegistered.listen(_onRegistered);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => _emit(message, opened: false),
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _emit(message, opened: true),
    );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _emit(initial, opened: true);
  }

  Future<void> bindAuthenticatedUser() async {
    _authenticated = true;
    if (!_ready) return;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (_registrationId != null) await _upload(_registrationId!);
      await _messaging.register();
    } catch (error, stackTrace) {
      // A missing Play Services/APNs setup must not block normal app use.
      debugPrint('Firebase push registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> unbindAuthenticatedUser() async {
    clearLocalUser();
    final generation = _userGeneration;
    try {
      await _repository.removePushRegistration();
    } catch (_) {
      // Logout must still complete if the server or FCM is unavailable.
    } finally {
      if (_ready && !_authenticated && generation == _userGeneration) {
        try {
          await _messaging.unregister().timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    }
  }

  PushEvent? takeEvent() {
    final value = _event;
    _event = null;
    return value;
  }

  Future<void> _onRegistered(String registrationId) async {
    _registrationId = registrationId;
    if (_authenticated) await _upload(registrationId);
  }

  Future<void> _upload(String registrationId) async {
    try {
      await _repository.registerPush(
        firebaseInstallationId: registrationId,
        platform: Platform.isIOS ? 'IOS' : 'ANDROID',
      );
    } catch (error, stackTrace) {
      // FCM retries registration on later app starts; notification setup must
      // never block the signed-in workspace.
      debugPrint('Firebase push registration upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _emit(RemoteMessage remote, {required bool opened}) {
    if (!_authenticated) return;
    final data = remote.data;
    _event = PushEvent(
      kind: data['kind'] ?? 'GENERAL',
      title: remote.notification?.title ?? data['title'] ?? 'Monetizer',
      message: remote.notification?.body ?? data['message'] ?? '',
      opened: opened,
      companyId: data['companyId'],
      companyName: data['companyName'],
      notificationId: data['notificationId'],
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _registrationSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    super.dispose();
  }
}
