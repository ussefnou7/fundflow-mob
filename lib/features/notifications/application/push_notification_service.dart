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
    bool? isIOS,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) : _repository = repository,
       _providedMessaging = messaging,
       _isIOS = isIOS ?? (!kIsWeb && Platform.isIOS),
       _retryDelay = retryDelay;

  final NotificationRepository _repository;
  final FirebaseMessaging? _providedMessaging;
  final bool _isIOS;
  final Duration _retryDelay;
  FirebaseMessaging get _messaging =>
      _providedMessaging ?? FirebaseMessaging.instance;
  bool _ready = false;

  /// What happened while setting up push on this device, newest last; shown
  /// by a long press on the notifications title, since store builds have no
  /// console to read.
  final List<String> diagnostics = [];

  void _note(String line) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    diagnostics.add('$time $line');
    if (diagnostics.length > 60) diagnostics.removeAt(0);
    debugPrint('push: $line');
  }

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
      _note('Firebase ready');
      if (_authenticated) await bindAuthenticatedUser();
    } catch (error) {
      // Inbox remains available without push support.
      _note('Firebase start failed: $error');
    }
  }

  /// The diagnostics panel's "retry" button.
  Future<void> retryRegistration() {
    _note('retry requested');
    return bindAuthenticatedUser();
  }

  /// Tests run without Firebase.initializeApp, which [start] would call.
  @visibleForTesting
  void markReady() => _ready = true;

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
    if (!_ready) {
      _note('signed in, waiting for Firebase');
      return;
    }
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _note('permission: ${settings.authorizationStatus.name}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      await _messaging.setAutoInitEnabled(true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (_registrationId != null) await _upload(_registrationId!);
      await _register();
    } catch (error, stackTrace) {
      // A missing Play Services/APNs setup must not block normal app use.
      _note('registration gave up: $error');
      debugPrint('Firebase push registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// On iOS, FCM registers only once APNs has handed the app its device
  /// token, which arrives asynchronously after the permission prompt. Calling
  /// register() before that fails, so wait for the token, and retry a failed
  /// registration a few times instead of giving up for the whole session.
  Future<void> _register() async {
    final generation = _userGeneration;
    Object? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!_authenticated || generation != _userGeneration) return;
      if (_isIOS) await _waitForApnsToken();
      try {
        await _messaging.register();
        _note('FCM register call ok (attempt ${attempt + 1})');
        return;
      } catch (error) {
        lastError = error;
        _note('FCM register attempt ${attempt + 1} failed: $error');
        await Future<void>.delayed(_retryDelay * (attempt + 1) * 2);
      }
    }
    if (lastError != null) throw lastError;
  }

  Future<void> _waitForApnsToken() async {
    for (var i = 0; i < 20; i++) {
      final token = await _messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        _note('APNs token ok (${token.length} chars)');
        return;
      }
      await Future<void>.delayed(_retryDelay);
    }
    _note('APNs token still missing after waiting');
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
    _note(
      'FCM registered: ${registrationId.substring(0, registrationId.length.clamp(0, 8))}…',
    );
    _registrationId = registrationId;
    if (_authenticated) await _upload(registrationId);
  }

  Future<void> _upload(String registrationId) async {
    try {
      await _repository.registerPush(
        firebaseInstallationId: registrationId,
        platform: _isIOS ? 'IOS' : 'ANDROID',
      );
      _note('sent to server');
    } catch (error, stackTrace) {
      _note('sending to server failed: $error');
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
