import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyToken = 'auth_token';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyCurrentOrgSlug = 'current_org_slug';
  static const String _keyCurrentOrgId = 'current_org_id';

  Future<void> saveAuthSession({
    required String token,
    required String role,
    required String name,
    required String email,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUserRole, value: role);
    await _storage.write(key: _keyUserName, value: name);
    await _storage.write(key: _keyUserEmail, value: email);
  }

  Future<void> saveCurrentOrgSlug(String slug) async {
    await _storage.write(key: _keyCurrentOrgSlug, value: slug);
  }

  Future<void> saveUserRole(String role) async {
    await _storage.write(key: _keyUserRole, value: role);
  }

  Future<String?> getCurrentOrgSlug() async {
    return await _storage.read(key: _keyCurrentOrgSlug);
  }

  Future<void> saveCurrentOrgId(String id) async {
    await _storage.write(key: _keyCurrentOrgId, value: id);
  }

  Future<String?> getCurrentOrgId() async {
    return await _storage.read(key: _keyCurrentOrgId);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: _keyUserName);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
