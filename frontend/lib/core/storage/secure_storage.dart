// On web we use localStorage directly (Web Crypto is unavailable over HTTP).
// On mobile we use flutter_secure_storage (encrypted).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web/web.dart' as web;

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  // ── internal helpers ────────────────────────────────────────────

  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      web.window.localStorage.setItem(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  static Future<String?> _read(String key) async {
    if (kIsWeb) {
      return web.window.localStorage.getItem(key);
    }
    return _storage.read(key: key);
  }

  static Future<void> _delete(String key) async {
    if (kIsWeb) {
      web.window.localStorage.removeItem(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  // ── Access Token ────────────────────────────────────────────────

  static Future<void> setAccessToken(String token) => _write(_accessTokenKey, token);
  static Future<String?> getAccessToken() => _read(_accessTokenKey);
  static Future<void> deleteAccessToken() => _delete(_accessTokenKey);

  // ── Refresh Token ───────────────────────────────────────────────

  static Future<void> setRefreshToken(String token) => _write(_refreshTokenKey, token);
  static Future<String?> getRefreshToken() => _read(_refreshTokenKey);
  static Future<void> deleteRefreshToken() => _delete(_refreshTokenKey);

  // ── Clear all ───────────────────────────────────────────────────

  static Future<void> clearAll() async {
    if (kIsWeb) {
      web.window.localStorage.removeItem(_accessTokenKey);
      web.window.localStorage.removeItem(_refreshTokenKey);
    } else {
      await _storage.deleteAll();
    }
  }
}
