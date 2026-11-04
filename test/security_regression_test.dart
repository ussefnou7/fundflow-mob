import 'package:flutter/material.dart';
import 'package:fundflow_mob/app/app.dart';
import 'package:fundflow_mob/features/workspace/presentation/workspace_shell.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/network/request_keys.dart';
import 'package:fundflow_mob/core/config/app_config.dart';
import 'package:fundflow_mob/core/format/exact_decimal.dart';
import 'package:fundflow_mob/features/auth/application/auth_controller.dart';
import 'package:fundflow_mob/features/auth/domain/auth_gateway.dart';
import 'package:fundflow_mob/features/auth/domain/auth_user.dart';
import 'package:fundflow_mob/features/custody/data/custody_repository.dart';
import 'package:fundflow_mob/features/workspace/application/workspace_controller.dart';
import 'package:fundflow_mob/features/workspace/data/workspace_repository.dart';
import 'package:fundflow_mob/features/workspace/domain/workspace_context.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('session expiry removes open dialogs containing financial data', (
    tester,
  ) async {
    final auth = AuthController(_Gateway())
      ..user = _Gateway.account
      ..status = AuthStatus.authenticated;
    final client = ApiClient(dio: Dio(), cookieJar: CookieJar());
    final workspace = WorkspaceController.seeded(
      custody: CustodyRepository(client),
      context: const WorkspaceContext(
        theme: FundFlowBrand.evergreen,
        companyName: 'Company',
        permissions: {},
        activeCompanyId: 'company',
      ),
    );
    auth.onSessionEnded = workspace.reset;
    await tester.pumpWidget(
      FundFlowApp(authController: auth, workspaceController: workspace),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(WorkspaceShell));
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('financial-secret')),
    );
    await tester.pumpAndSettle();
    expect(find.text('financial-secret'), findsOneWidget);
    auth.expireSession();
    await tester.pumpAndSettle();
    expect(find.text('financial-secret'), findsNothing);
    expect(find.text('كود العميل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'offline logout clears identity and workspace despite server failure',
    () async {
      final gateway = _Gateway();
      final auth = AuthController(gateway);
      await auth.initialize();
      var reset = 0;
      auth.onSessionEnded = () => reset++;
      await auth.logout();
      expect(auth.user, isNull);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.submitting, isFalse);
      expect(reset, greaterThan(0));
    },
  );

  test(
    'MFA challenge stays unauthenticated and forwards the second factor',
    () async {
      final gateway = _Gateway()..needsMfa = true;
      final auth = AuthController(gateway);
      expect(
        await auth.login(tenant: 'T', username: 'u', password: 'p'),
        isFalse,
      );
      expect(auth.mfaRequired, isTrue);
      expect(auth.status, isNot(AuthStatus.authenticated));
      expect(
        await auth.login(
          tenant: 'T',
          username: 'u',
          password: 'p',
          code: '123456',
        ),
        isTrue,
      );
      expect(auth.status, AuthStatus.authenticated);
    },
  );

  test('stale workspace reply cannot repopulate account after reset', () async {
    final client = ApiClient(dio: Dio(), cookieJar: CookieJar());
    final repository = _DelayedWorkspace(client);
    final workspace = WorkspaceController(
      repository: repository,
      custody: CustodyRepository(client),
    );
    final pending = workspace.initialize();
    workspace.reset();
    repository.reply.complete(
      const WorkspaceContext(
        theme: FundFlowBrand.evergreen,
        companyName: 'Old tenant',
        permissions: {},
        activeCompanyId: 'old',
      ),
    );
    await pending;
    expect(workspace.context, isNull);
    expect(workspace.loading, isFalse);
  });

  test(
    'financial receipt survives restart and is discarded only after success',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final keys = <String>[];
      var fail = true;
      ApiClient create() {
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.example.test',
            validateStatus: (_) => true,
          ),
        );
        dio.httpClientAdapter = _Adapter((options) async {
          if (options.path.endsWith('/csrf')) {
            return ResponseBody.fromString(
              '{"headerName":"X-CSRF","token":"csrf"}',
              200,
              headers: {
                'content-type': ['application/json'],
              },
            );
          }
          keys.add(options.headers['Idempotency-Key'] as String);
          expect(options.headers['X-Company-Id'], 'company');
          if (fail) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return ResponseBody.fromString(
            '{"id":"one"}',
            201,
            headers: {
              'content-type': ['application/json'],
            },
          );
        });
        return ApiClient(
            dio: dio,
            cookieJar: CookieJar(),
            requestKeys: RequestKeys(prefs),
          )
          ..operationScope = 'user'
          ..companyId = 'company';
      }

      await expectLater(
        create().postJson('/custody/requests', {'amount': '10.00'}),
        throwsA(isA<ApiConnectionException>()),
      );
      fail = false;
      await create().postJson('/custody/requests', {'amount': '10.00'});
      await create().postJson('/custody/requests', {'amount': '10.00'});
      expect(keys[0], keys[1]);
      expect(keys[2], isNot(keys[1]));
      expect(
        prefs.getKeys().where((k) => k.startsWith('fundflow.receipt.')),
        isEmpty,
      );
    },
  );

  test(
    'late response cannot restore cookies after local session clear',
    () async {
      final response = Completer<ResponseBody>();
      final entered = Completer<void>();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _Adapter((options) {
        entered.complete();
        return response.future;
      });
      final jar = CookieJar();
      final client = ApiClient(dio: dio, cookieJar: jar);
      final pending = client.get('/data');
      final assertion = expectLater(
        pending,
        throwsA(isA<ApiConnectionException>()),
      );
      await entered.future;
      await client.clearSession();
      response.complete(
        ResponseBody.fromString(
          '{}',
          200,
          headers: {
            'set-cookie': ['SESSION=old; Path=/'],
            'content-type': ['application/json'],
          },
        ),
      );
      await assertion;
      expect(
        await jar.loadForRequest(
          Uri.parse('https://api.example.test/api/data'),
        ),
        isEmpty,
      );
    },
  );

  test(
    '401 expires the session while 403 keeps an authorized account signed in',
    () async {
      var status = 403;
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.example.test',
          validateStatus: (_) => true,
        ),
      );
      dio.httpClientAdapter = _Adapter(
        (_) async => ResponseBody.fromString('{}', status),
      );
      final client = ApiClient(dio: dio, cookieJar: CookieJar());
      var expired = 0;
      client.onSessionExpired = () => expired++;
      await client.get('/data');
      expect(expired, 0);
      status = 401;
      await client.get('/data');
      expect(expired, 1);
    },
  );

  test('decimals preserve large amounts and match server HALF_UP per line', () {
    expect(
      ExactDecimal.parse('9007199254740993.01').toString(),
      '9007199254740993.01',
    );
    expect(ExactDecimal.parse('1.005').rounded(2).toString(), '1.01');
    expect(ExactDecimal.parse('-1.005').rounded(2).toString(), '-1.01');
    expect(
      (ExactDecimal.parse('0.1') + ExactDecimal.parse('0.2')).toString(),
      '0.3',
    );
    expect(ExactDecimal.parse('12.345').percent.toString(), '0.12345');
    expect(ExactDecimal.parse('١٢٣٫٤٥').toString(), '123.45');
    expect(ExactDecimal.tryParse('NaN'), isNull);
    expect(ExactDecimal.tryParse('Infinity'), isNull);
  });

  test('release rejects development and insecure endpoints', () {
    for (final url in [
      'http://example.com',
      'http://192.168.1.17:8080',
      'https://localhost',
      'https://user:pass@api.example.com',
    ]) {
      expect(
        () => AppConfig.validate(release: true, url: url),
        throwsStateError,
      );
    }
    expect(
      () => AppConfig.validate(release: true, url: 'https://api.example.com'),
      returnsNormally,
    );
  });

  test('debug requires an absolute HTTP endpoint', () {
    expect(
      () => AppConfig.validate(release: false, url: 'http://192.168.1.17:8080'),
      returnsNormally,
    );
    for (final url in ['192.168.1.17:8080', 'ftp://example.com']) {
      expect(
        () => AppConfig.validate(release: false, url: url),
        throwsStateError,
      );
    }
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

class _Gateway implements AuthGateway {
  bool needsMfa = false;
  static const account = AuthUser(
    id: 'u',
    name: 'User',
    username: 'user',
    platformAdmin: false,
  );
  @override
  String get savedTenant => 'T';
  @override
  Future<AuthUser?> currentUser() async => account;
  @override
  Future<void> logout() async => throw const ApiConnectionException('offline');
  @override
  Future<AuthUser> login({
    required String tenant,
    required String username,
    required String password,
    String? code,
  }) async {
    if (needsMfa && code != '123456') {
      throw const AuthFailure('code required', mfaRequired: true);
    }
    return account;
  }
}

class _DelayedWorkspace extends WorkspaceRepository {
  _DelayedWorkspace(super.client);
  final reply = Completer<WorkspaceContext>();
  @override
  Future<WorkspaceContext> load() => reply.future;
}
