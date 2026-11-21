import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/push_service.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../models/app_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo, this._tokens, this._push, ApiClient api) {
    api.onUnauthorized = () {
      if (status == AuthStatus.authenticated) _signOutLocally(message: 'Your session expired. Please log in again.');
    };
  }

  final AuthRepository _repo;
  final TokenStorage _tokens;
  final PushService _push;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? sessionMessage;

  /// Restore the session on app start.
  Future<void> bootstrap() async {
    final token = await _tokens.read();
    if (token == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      user = await _repo.me();
      status = AuthStatus.authenticated;
      _registerPush();
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _tokens.clear();
      // Offline with a saved token: still show login so the user can retry.
      status = AuthStatus.unauthenticated;
      sessionMessage = e.isUnauthorized ? null : e.message;
    }
    notifyListeners();
  }

  Future<void> login(String login, String password) async {
    final (token, u) = await _repo.login(login.trim(), password);
    await _signIn(token, u);
  }

  Future<void> register(Map<String, dynamic> data) async {
    final (token, u) = await _repo.register(data);
    await _signIn(token, u);
  }

  Future<void> refreshUser() async {
    user = await _repo.me();
    notifyListeners();
  }

  void setUser(AppUser u) {
    user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {
      // Token may already be invalid; sign out locally anyway.
    }
    await _signOutLocally();
  }

  Future<void> _signIn(String token, AppUser u) async {
    await _tokens.write(token);
    user = u;
    sessionMessage = null;
    status = AuthStatus.authenticated;
    notifyListeners();
    _registerPush();
  }

  Future<void> _signOutLocally({String? message}) async {
    await _tokens.clear();
    user = null;
    sessionMessage = message;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _registerPush() async {
    final token = await _push.token();
    if (token != null) {
      try {
        await _repo.saveFcmToken(token);
      } catch (_) {}
    }
  }
}
