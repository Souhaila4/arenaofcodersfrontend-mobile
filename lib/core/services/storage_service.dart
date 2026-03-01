import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:arena/core/models/auth_models.dart';

class StorageService {
  static const _tokenKey = 'access_token';
  static const _userKey = 'user_data';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Token ──

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ── User ──

  Future<void> saveUser(AuthUser user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<AuthUser?> getUser() async {
    final data = await _storage.read(key: _userKey);
    if (data == null) return null;
    return AuthUser.fromJson(jsonDecode(data));
  }

  Future<void> deleteUser() async {
    await _storage.delete(key: _userKey);
  }

  // ── Clear all ──

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
