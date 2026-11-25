import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'request_keys.dart';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

class ApiClient {
  ApiClient({required this.dio, required this.cookieJar, this.requestKeys}) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['sessionGeneration'] = _generation;
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.requestOptions.extra['sessionGeneration'] !=
              _generation) {
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                type: DioExceptionType.cancel,
              ),
            );
          } else {
            handler.next(response);
          }
        },
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));
  }

  final Dio dio;
  final CookieJar cookieJar;
  final RequestKeys? requestKeys;
  String? operationScope;
  String? companyId;

  bool _financialCreation(String path) =>
      path == '/custody/expenses' ||
      path == '/custody/transfers' ||
      path == '/custody/requests' ||
      path == '/contractor-extracts' ||
      path == '/scm/purchase-requests' ||
      path == '/scm/purchase-orders' ||
      path == '/scm/cash-purchases' ||
      RegExp(
        r'^/treasuries/[^/]+/(movements|direct-expenses|returns)$',
      ).hasMatch(path);

  Future<Response<dynamic>> _write(
    String path,
    Object payload,
    Future<Response<dynamic>> Function(Map<String, String>) send, {
    List<String> files = const [],
  }) async {
    final keys = requestKeys;
    if (!_financialCreation(path) || keys == null) return send(const {});
    final scope = operationScope;
    final company = companyId;
    if (scope == null || company == null) {
      throw const ApiConnectionException(
        'أعد تحميل بيانات الشركة قبل تسجيل العملية.',
      );
    }
    final hashes = <String>[];
    for (final path in files) {
      hashes.add(
        '${path.split(Platform.pathSeparator).last}:${await sha256.bind(File(path).openRead()).first}',
      );
    }
    final identity = keys.identity(
      '${dio.options.baseUrl}:$scope:$company',
      path,
      [payload, hashes],
    );
    final key = await keys.acquire(identity);
    if (operationScope != scope || companyId != company) {
      throw const ApiConnectionException(
        'تغير الحساب أو الشركة؛ أعد فتح النموذج.',
      );
    }
    try {
      final response = await send({
        'Idempotency-Key': key,
        'X-Company-Id': company,
      });
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        await keys.complete(identity);
      }
      return response;
    } on ApiConnectionException {
      throw const ApiConnectionException(
        'لم يتأكد وصول العملية. أعد المحاولة بنفس البيانات للتحقق دون تكرارها، أو راجع السجل قبل إنشاء عملية بديلة.',
      );
    }
  }

  Map<String, dynamic>? _csrf;
  void Function()? onSessionExpired;
  int _generation = 0;

  static Future<ApiClient> create() async {
    final support = await getApplicationSupportDirectory();
    final legacy = Directory('${support.path}/fundflow-cookies');
    if (await legacy.exists()) await legacy.delete(recursive: true);
    final cookieJar = CookieJar();
    AppConfig.validate();
    final baseUrl = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
        headers: const {'Accept': 'application/json'},
      ),
    );
    return ApiClient(
      dio: dio,
      cookieJar: cookieJar,
      requestKeys: RequestKeys(await SharedPreferences.getInstance()),
    );
  }

  Future<Response<dynamic>> get(String path) =>
      _networkRequest(() => dio.get<dynamic>('/api$path'));

  Future<Response<List<int>>> getBytes(String path) => _networkRequest(
    () => dio.get<List<int>>(
      '/api$path',
      options: Options(responseType: ResponseType.bytes),
    ),
  );

  Future<Response<dynamic>> postForm(
    String path,
    Map<String, String> values,
  ) async {
    final csrf = await _csrfToken();
    return _networkRequest(
      () => dio.post<dynamic>(
        '/api$path',
        data: values,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {csrf.headerName: csrf.token},
        ),
      ),
    );
  }

  Future<Response<dynamic>> postJson(
    String path,
    Map<String, dynamic> values,
  ) async {
    final csrf = await _csrfToken();
    return _write(
      path,
      values,
      (receiptHeaders) => _networkRequest(
        () => dio.post<dynamic>(
          '/api$path',
          data: values,
          options: Options(
            contentType: Headers.jsonContentType,
            headers: {csrf.headerName: csrf.token, ...receiptHeaders},
          ),
        ),
      ),
    );
  }

  Future<Response<dynamic>> putJson(
    String path,
    Map<String, dynamic> values,
  ) async {
    final csrf = await _csrfToken();
    return _networkRequest(
      () => dio.put<dynamic>(
        '/api$path',
        data: values,
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {csrf.headerName: csrf.token},
        ),
      ),
    );
  }

  Future<Response<dynamic>> delete(String path) async {
    final csrf = await _csrfToken();
    return _networkRequest(
      () => dio.delete<dynamic>(
        '/api$path',
        options: Options(headers: {csrf.headerName: csrf.token}),
      ),
    );
  }

  Future<Response<dynamic>> postMultipart(
    String path, {
    required String jsonPartName,
    required Map<String, dynamic> json,
    required String filePartName,
    required String filePath,
  }) async {
    final csrf = await _csrfToken();
    final form = FormData.fromMap({
      jsonPartName: MultipartFile.fromString(
        jsonEncode(json),
        contentType: DioMediaType.parse(Headers.jsonContentType),
      ),
      filePartName: await MultipartFile.fromFile(filePath),
    });
    return _write(
      path,
      json,
      (receiptHeaders) => _networkRequest(
        () => dio.post<dynamic>(
          '/api$path',
          data: form,
          options: Options(
            sendTimeout: const Duration(minutes: 5),
            headers: {csrf.headerName: csrf.token, ...receiptHeaders},
          ),
        ),
      ),
      files: [filePath],
    );
  }

  /// A JSON part beside one file per named part.
  Future<Response<dynamic>> postMultipartParts(
    String path, {
    required String jsonPartName,
    required Map<String, dynamic> json,
    required Map<String, String> files,
  }) async {
    final csrf = await _csrfToken();
    final form = FormData.fromMap({
      jsonPartName: MultipartFile.fromString(
        jsonEncode(json),
        contentType: DioMediaType.parse(Headers.jsonContentType),
      ),
      for (final file in files.entries)
        file.key: await MultipartFile.fromFile(file.value),
    });
    return _write(
      path,
      json,
      (receiptHeaders) => _networkRequest(
        () => dio.post<dynamic>(
          '/api$path',
          data: form,
          options: Options(
            sendTimeout: const Duration(minutes: 5),
            headers: {csrf.headerName: csrf.token, ...receiptHeaders},
          ),
        ),
      ),
      files: files.values.toList(),
    );
  }

  Future<Response<dynamic>> postMultipartFiles(
    String path, {
    required String jsonPartName,
    required Map<String, dynamic> json,
    required String filePartName,
    required List<String> filePaths,
  }) async {
    final csrf = await _csrfToken();
    final files = <MultipartFile>[];
    for (final path in filePaths) {
      files.add(await MultipartFile.fromFile(path));
    }
    final form = FormData.fromMap({
      jsonPartName: MultipartFile.fromString(
        jsonEncode(json),
        contentType: DioMediaType.parse(Headers.jsonContentType),
      ),
      if (files.isNotEmpty) filePartName: files,
    });
    return _write(
      path,
      json,
      (receiptHeaders) => _networkRequest(
        () => dio.post<dynamic>(
          '/api$path',
          data: form,
          options: Options(
            sendTimeout: const Duration(minutes: 5),
            headers: {csrf.headerName: csrf.token, ...receiptHeaders},
          ),
        ),
      ),
      files: filePaths,
    );
  }

  /// Plain form fields beside the files, for endpoints that read
  /// request parameters rather than a JSON part.
  Future<Response<dynamic>> postFieldsAndFiles(
    String path, {
    required Map<String, String> fields,
    required String filePartName,
    required List<String> filePaths,
  }) async {
    final csrf = await _csrfToken();
    final files = <MultipartFile>[];
    for (final path in filePaths) {
      files.add(await MultipartFile.fromFile(path));
    }
    final form = FormData.fromMap({...fields, filePartName: files});
    return _networkRequest(
      () => dio.post<dynamic>(
        '/api$path',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          headers: {csrf.headerName: csrf.token},
        ),
      ),
    );
  }

  Future<void> clearSession() async {
    _generation++;
    operationScope = null;
    companyId = null;
    _csrf = null;
    await cookieJar.deleteAll();
  }

  void clearCsrf() => _csrf = null;

  Future<_CsrfToken> _csrfToken() async {
    final cached = _csrf;
    if (cached != null) return _CsrfToken.fromJson(cached);
    final response = await _networkRequest(
      () => dio.get<dynamic>('/api/auth/csrf'),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw const ApiConnectionException('تعذر الاتصال بالخادم');
    }
    _csrf = Map<String, dynamic>.from(response.data as Map);
    return _CsrfToken.fromJson(_csrf!);
  }

  Future<T> _networkRequest<T>(Future<T> Function() request) async {
    final generation = _generation;
    try {
      final result = await request();
      if (generation != _generation) {
        throw const ApiConnectionException(
          'تم تغيير جلسة الدخول. أعد فتح الشاشة.',
        );
      }
      if (result is Response &&
          result.statusCode == 401 &&
          !result.requestOptions.path.startsWith('/api/auth/')) {
        await clearSession();
        onSessionExpired?.call();
      }
      return result;
    } on DioException catch (error) {
      throw ApiConnectionException.fromDio(error);
    }
  }
}

class _CsrfToken {
  const _CsrfToken({required this.headerName, required this.token});

  factory _CsrfToken.fromJson(Map<String, dynamic> json) {
    final headerName = json['headerName'];
    final token = json['token'];
    if (headerName is! String || token is! String) {
      throw const ApiConnectionException('استجابة الخادم غير صالحة');
    }
    return _CsrfToken(headerName: headerName, token: token);
  }

  final String headerName;
  final String token;
}

class ApiConnectionException implements Exception {
  const ApiConnectionException(this.message);

  factory ApiConnectionException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout =>
        'انتهت مهلة الاتصال. تأكد أن السيرفر يعمل ثم حاول مرة أخرى.',
      DioExceptionType.badCertificate =>
        'تعذر إنشاء اتصال آمن بالسيرفر. تحقق من إعدادات الاتصال.',
      DioExceptionType.cancel => 'تم إلغاء الطلب.',
      DioExceptionType.badResponse when status != null && status >= 500 =>
        'السيرفر غير متاح حاليًا. حاول مرة أخرى بعد قليل.',
      DioExceptionType.badResponse => 'تعذر إتمام الطلب. حاول مرة أخرى.',
      DioExceptionType.connectionError || DioExceptionType.unknown =>
        'السيرفر غير متاح حاليًا. تأكد أن السيرفر يعمل وأن الهاتف متصل بنفس الشبكة، ثم حاول مرة أخرى.',
    };
    return ApiConnectionException(message);
  }

  final String message;

  @override
  String toString() => message;
}
