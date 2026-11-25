import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _installationKey = 'fundflow.installationId';

/// This app install's stable id. Device login registers it with the user.
String installationIdOf(SharedPreferences prefs) {
  final existing = prefs.getString(_installationKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  final value = base64UrlEncode(bytes).replaceAll('=', '');
  prefs.setString(_installationKey, value);
  return value;
}
