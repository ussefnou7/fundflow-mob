import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static void validate({bool release = kReleaseMode, String url = apiBaseUrl}) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError(
        'API_BASE_URL must be an absolute HTTP or HTTPS URL without credentials.',
      );
    }
    if (release &&
        (uri.scheme != 'https' ||
            uri.host == 'localhost' ||
            RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(uri.host))) {
      throw StateError(
        'Release requires an HTTPS API_BASE_URL with a public hostname.',
      );
    }
  }

  /// The default is the workstation's Wi-Fi address (wlp3s0), not virbr0. If it
  /// changes, or for an emulator (http://10.0.2.2:8080), override it with:
  /// --dart-define=API_BASE_URL=http://<lan-ip>:8080
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.17:8080',
  );
}
