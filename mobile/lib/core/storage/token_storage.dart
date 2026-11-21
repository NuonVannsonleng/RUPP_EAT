import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sanctum token kept in the Android Keystore-backed secure storage.
class TokenStorage {
  static const _key = 'rupp_eat_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _cached;

  Future<String?> read() async => _cached ??= await _storage.read(key: _key);

  Future<void> write(String token) async {
    _cached = token;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _key);
  }
}
