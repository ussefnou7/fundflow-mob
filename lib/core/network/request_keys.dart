import 'dart:convert';
import 'dart:collection';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Only hashed request identities and random receipts are persisted; no financial payload.
/// A receipt survives crashes until the server has definitively answered the request.
class RequestKeys {
  RequestKeys(this.preferences);
  final SharedPreferences preferences;

  static dynamic canonical(dynamic value) {
    if (value is Map) {
      return SplayTreeMap<String, dynamic>.from(
        value.map((key, item) => MapEntry(key.toString(), canonical(item))),
      );
    }
    if (value is List) {
      return value.map(canonical).toList();
    }
    return value;
  }

  String identity(String scope, String path, Object payload) =>
      'fundflow.receipt.${sha256.convert(utf8.encode(jsonEncode([scope, path, canonical(payload)])))}';

  Future<String> acquire(String identity) async {
    final previous = preferences.getString(identity);
    if (previous != null) return previous;
    final random = Random.secure();
    final key = base64UrlEncode(
      List.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    if (!await preferences.setString(identity, key)) {
      throw StateError('Cannot save operation receipt');
    }
    return key;
  }

  Future<void> complete(String identity) async {
    await preferences.remove(identity);
  }
}
