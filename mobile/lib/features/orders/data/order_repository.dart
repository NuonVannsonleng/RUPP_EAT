import '../../../core/network/api_client.dart';
import '../models/order.dart';

class OrderRepository {
  OrderRepository(this._api);
  final ApiClient _api;

  Future<Paged<Order>> list({String? status, int page = 1}) =>
      _api.getPaged('/orders', Order.fromJson, query: {'status': status, 'page': page, 'per_page': 15});

  Future<Order> get(String id) async => Order.fromJson(((await _api.get('/orders/$id'))['data'] as Map).cast());

  /// [idempotencyKey] makes a double-tap or network retry return the same order.
  Future<Order> place(Map<String, dynamic> body, String idempotencyKey) async {
    final res = await _api.post('/orders', data: body, headers: {'Idempotency-Key': idempotencyKey});
    return Order.fromJson((res['data'] as Map).cast());
  }

  Future<Order> cancel(String id, String reason) async =>
      Order.fromJson(((await _api.patch('/orders/$id/status', data: {'status': 'cancelled', 'reason': reason}))['data'] as Map).cast());

  /// Returns (message, skipped item names).
  Future<(String, List<String>)> reorder(String id) async {
    final res = await _api.post('/orders/$id/reorder');
    return (res['message'] as String? ?? '', ((res['data'] as Map)['skipped'] as List).cast<String>());
  }

  Future<String> review(String orderId, int rating, String? comment, List<Map<String, dynamic>> products) async =>
      (await _api.post('/orders/$orderId/reviews', data: {'rating': rating, 'comment': comment, 'products': products}))['message'] ?? '';

  Future<Paged<AppNotification>> notifications({int page = 1}) =>
      _api.getPaged('/notifications', AppNotification.fromJson, query: {'page': page});

  Future<int> unreadCount() async => ((await _api.get('/notifications/unread-count'))['data'] as Map)['unread_count'] as int;

  Future<void> markRead(String id) => _api.post('/notifications/$id/read');

  Future<void> markAllRead() => _api.post('/notifications/read-all');

  Future<List<Map<String, dynamic>>> supportTickets() async =>
      ((await _api.get('/support-tickets'))['data'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList();

  Future<String> createSupportTicket(String subject, String message, {String? orderId}) async =>
      (await _api.post('/support-tickets', data: {'subject': subject, 'message': message, 'order_id': orderId}))['message'] ?? '';
}
