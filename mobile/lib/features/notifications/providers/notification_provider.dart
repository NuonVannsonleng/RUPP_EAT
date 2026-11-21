import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../orders/data/order_repository.dart';
import '../../orders/models/order.dart';

/// Notification inbox + unread badge. Polls the API so it works without Firebase.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._repo);
  final OrderRepository _repo;

  int unread = 0;
  List<AppNotification> items = [];
  bool loading = false;
  String? error;
  Timer? _timer;

  /// Fired when the unread count goes up (a new order update arrived).
  void Function(int newCount)? onNew;

  void start() {
    _timer?.cancel();
    refreshCount();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refreshCount());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    unread = 0;
    items = [];
  }

  Future<void> refreshCount() async {
    try {
      final count = await _repo.unreadCount();
      if (count > unread) onNew?.call(count);
      if (count != unread) {
        unread = count;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _repo.notifications();
      items = page.items;
      unread = (page.extra['unread_count'] as int?) ?? items.where((n) => !n.isRead).length;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    n.readAt = DateTime.now();
    unread = (unread - 1).clamp(0, 9999);
    notifyListeners();
    try {
      await _repo.markRead(n.id);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    for (final n in items) {
      n.readAt ??= DateTime.now();
    }
    unread = 0;
    notifyListeners();
    await _repo.markAllRead();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
