import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/network/api_error.dart';

void main() {
  group('ApiClient connection errors', () {
    test(
      'shows a clean Arabic message when the server is unreachable',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException.connectionError(
                requestOptions: options,
                reason: 'Connection refused',
              ),
            ),
          ),
        );
        final client = ApiClient(dio: dio, cookieJar: CookieJar());

        await expectLater(
          client.get('/health'),
          throwsA(
            isA<ApiConnectionException>()
                .having(
                  (error) => error.toString(),
                  'message',
                  contains('السيرفر غير متاح حاليًا'),
                )
                .having(
                  (error) => error.toString(),
                  'does not leak Dio details',
                  isNot(contains('DioException')),
                ),
          ),
        );
      },
    );

    test('maps server outages to a specific response message', () {
      final request = RequestOptions(path: '/api/custody/dashboard');
      final error = ApiError.fromResponse(
        Response<dynamic>(requestOptions: request, statusCode: 503),
      );

      expect(error.toString(), contains('السيرفر غير متاح حاليًا'));
    });
  });
}
