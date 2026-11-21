import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../models/delivery.dart';

class DriverStats {
  DriverStats(this.raw);
  final Map<String, dynamic> raw;
  int get todayDeliveries => toInt(raw['today_deliveries']);
  double get todayEarnings => toDouble(raw['today_earnings']);
  int get weekDeliveries => toInt(raw['week_deliveries']);
  double get weekEarnings => toDouble(raw['week_earnings']);
  int get totalDeliveries => toInt(raw['total_deliveries']);
  int get availableRequests => toInt(raw['available_requests']);
}

class DriverDashboard {
  DriverDashboard({required this.isOnline, required this.verificationStatus, required this.isActive, required this.stats, required this.active});
  final bool isOnline;
  final String verificationStatus;
  final bool isActive;
  final DriverStats stats;
  final List<Delivery> active;

  bool get isVerified => verificationStatus == 'verified';
}

class DriverRepository {
  DriverRepository(this._api);
  final ApiClient _api;

  Delivery _one(Map<String, dynamic> res) => Delivery.fromJson((res['data'] as Map).cast());

  Future<DriverDashboard> dashboard() async {
    final d = ((await _api.get('/driver/dashboard'))['data'] as Map).cast<String, dynamic>();
    final p = (d['profile'] as Map).cast<String, dynamic>();
    return DriverDashboard(
      isOnline: p['is_online'] == true,
      verificationStatus: p['verification_status'] ?? 'pending',
      isActive: p['is_active'] == true,
      stats: DriverStats((d['stats'] as Map).cast()),
      active: (d['active_deliveries'] as List).map((e) => Delivery.fromJson((e as Map).cast())).toList(),
    );
  }

  Future<void> sendLocation(double lat, double lng, double? heading) =>
      _api.post('/driver/location', data: {'latitude': lat, 'longitude': lng, 'heading': heading});

  Future<bool> setOnline(bool online) async => ((await _api.post('/driver/availability', data: {'is_online': online}))['data'] as Map)['is_online'] == true;

  /// type: available | active | completed | cancelled | history
  Future<Paged<Delivery>> deliveries(String type, {int page = 1}) async {
    final body = await _api.get('/driver/deliveries', query: {'type': type, 'page': page});
    final list = (body['data'] as List? ?? []).map((e) => Delivery.fromJson((e as Map).cast())).toList();
    final meta = (body['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    return Paged(list, toInt(meta['current_page'] ?? 1), toInt(meta['last_page'] ?? 1), extra: {'message': body['message']});
  }

  Future<Delivery> get(String id) async => _one(await _api.get('/driver/deliveries/$id'));

  Future<Delivery> accept(String id) async => _one(await _api.post('/driver/deliveries/$id/accept'));

  Future<void> reject(String id) => _api.post('/driver/deliveries/$id/reject');

  Future<void> release(String id, String? reason) => _api.post('/driver/deliveries/$id/release', data: {'reason': reason});

  /// status: picked_up | arriving | delivered. Returns (delivery, message).
  Future<(Delivery, String)> updateStatus(String id, String status) async {
    final res = await _api.patch('/driver/deliveries/$id/status', data: {'status': status});
    return (_one(res), res['message'] as String? ?? '');
  }
}
