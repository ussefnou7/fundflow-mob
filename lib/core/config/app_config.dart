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

  /// The production server. Release builds use it unless API_BASE_URL is
  /// given, so a store build never points at a workstation.
  static const productionUrl =
      'https://fundflow-production-bb03d785.up.railway.app';

  /// The web app, which serves the public privacy and support pages the
  /// stores require. `--dart-define=WEB_BASE_URL=https://<web-host>`
  /// overrides it; an empty value hides the links.
  static const webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://fundflow-stg.up.railway.app',
  );

  static const _override = String.fromEnvironment('API_BASE_URL');

  /// Debug and profile default to the workstation's Wi-Fi address (wlp3s0),
  /// never virbr0 (192.168.122.x), which a phone cannot reach. If it changes,
  /// or for an emulator (http://10.0.2.2:8080), override it with:
  /// `--dart-define=API_BASE_URL=http://<lan-ip>:8080`
  static const apiBaseUrl = _override != ''
      ? _override
      : kReleaseMode
      ? productionUrl
      : 'http://192.168.1.28:8080';
}
