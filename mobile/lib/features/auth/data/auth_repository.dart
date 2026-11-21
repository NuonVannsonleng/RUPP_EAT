import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/app_user.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  /// Returns (token, user).
  Future<(String, AppUser)> login(String login, String password) async {
    final res = await _api.post('/login', data: {'login': login, 'password': password, 'device_name': 'android', 'app': 'mobile'});
    final data = (res['data'] as Map).cast<String, dynamic>();
    return (data['token'] as String, AppUser.fromJson((data['user'] as Map).cast()));
  }

  Future<(String, AppUser)> register(Map<String, dynamic> body) async {
    final res = await _api.post('/register', data: {...body, 'device_name': 'android'});
    final data = (res['data'] as Map).cast<String, dynamic>();
    return (data['token'] as String, AppUser.fromJson((data['user'] as Map).cast()));
  }

  /// Driver application: account starts 'pending' until an admin verifies it.
  Future<(String, AppUser)> registerDriver(Map<String, dynamic> body) async {
    final res = await _api.post('/register/driver', data: {...body, 'device_name': 'android'});
    final data = (res['data'] as Map).cast<String, dynamic>();
    return (data['token'] as String, AppUser.fromJson((data['user'] as Map).cast()));
  }

  Future<AppUser> me() async => AppUser.fromJson(((await _api.get('/me'))['data'] as Map).cast());

  Future<void> logout() => _api.post('/logout');

  Future<String> forgotPassword(String email) async => (await _api.post('/forgot-password', data: {'email': email}))['message'] ?? '';

  Future<String> resetPassword(String email, String code, String password) async =>
      (await _api.post('/reset-password', data: {'email': email, 'code': code, 'password': password, 'password_confirmation': password}))['message'] ?? '';

  Future<AppUser> updateProfile(Map<String, dynamic> fields, {String? avatarPath}) async {
    final Object body = avatarPath == null
        ? fields
        : FormData.fromMap({...fields, 'avatar': await MultipartFile.fromFile(avatarPath)});
    final res = await _api.post('/me', data: body);
    return AppUser.fromJson((res['data'] as Map).cast());
  }

  Future<String> changePassword(String current, String password) async =>
      (await _api.put('/me/password', data: {'current_password': current, 'password': password, 'password_confirmation': password}))['message'] ?? '';

  Future<void> saveFcmToken(String? token) => _api.put('/me/fcm-token', data: {'fcm_token': token});
}
