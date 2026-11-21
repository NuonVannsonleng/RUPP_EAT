import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/maps/campus_map_data.dart';
import '../../../core/maps/campus_map_view.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

/// Live map on the customer's order screen: store, their classroom building and
/// (while the order is on its way) the driver's real GPS position, refreshed every 5 s.
class OrderTrackingMap extends StatefulWidget {
  const OrderTrackingMap({super.key, required this.orderId, required this.active});
  final String orderId;
  final bool active;

  @override
  State<OrderTrackingMap> createState() => _OrderTrackingMapState();
}

class _OrderTrackingMapState extends State<OrderTrackingMap> {
  CampusMap? _campus;
  Map<String, dynamic>? _t;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<CampusMapRepository>().load().then((c) {
      if (mounted) setState(() => _campus = c);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
    _load();
    if (widget.active) _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<ApiClient>().get('/orders/${widget.orderId}/tracking');
      if (mounted) setState(() => _t = (r['data'] as Map).cast<String, dynamic>());
    } on ApiException catch (e) {
      if (mounted && _t == null) setState(() => _error = e.message);
    }
  }

  LatLng? _ll(Map? m) {
    if (m == null || m['latitude'] == null || m['longitude'] == null) return null;
    return LatLng(toDouble(m['latitude']), toDouble(m['longitude']));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return const SizedBox.shrink();
    if (_campus == null || _t == null) {
      return const SizedBox(height: 220, child: Card(child: Center(child: CircularProgressIndicator())));
    }
    final t = _t!;
    final store = _ll(t['store'] as Map?);
    final dest = _ll(t['destination'] as Map?);
    final driverMap = t['driver'] as Map?;
    final driver = _ll(driverMap);
    final updated = parseDate(driverMap?['updated_at']);

    final pins = <CampusPin>[
      if (store != null) CampusPin(id: 'store', position: store, title: (t['store'] as Map)['name'], subtitle: (t['store'] as Map)['location']),
      if (dest != null)
        CampusPin(
          id: 'dest',
          position: dest,
          kind: PinKind.destination,
          title: '${(t['destination'] as Map)['building']}',
          subtitle: '${(t['destination'] as Map)['floor'] ?? ''} · ${(t['destination'] as Map)['room'] ?? ''}',
        ),
      if (driver != null) CampusPin(id: 'driver', position: driver, kind: PinKind.driver, title: driverMap!['name'] ?? 'Driver', subtitle: 'Your driver'),
    ];
    // Route: driver → store (before pickup) or driver → you (after pickup); otherwise store → you.
    final pickedUp = t['status'] == 'on_the_way';
    final route = <LatLng>[
      if (driver != null) driver,
      if (driver == null || !pickedUp) ?store,
      ?dest,
    ];

    String caption;
    if (driver != null && dest != null) {
      final m = metresBetween(driver, pickedUp ? dest : (store ?? dest)).round();
      caption = pickedUp ? '${driverMap!['name']} is about $m m from your building' : '${driverMap!['name']} is $m m from the store';
    } else if (t['fulfillment_method'] == 'pickup') {
      caption = 'Pick up at ${(t['store'] as Map)['name']} · ${(t['store'] as Map)['location']}';
    } else {
      caption = 'The driver appears here once they accept your order';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
          height: 230,
          child: CampusMapView(campus: _campus!, pins: pins, route: route.length >= 2 ? route : const [], fitPins: true, compact: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(children: [
            Icon(driver != null ? Icons.delivery_dining_rounded : Icons.map_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(caption, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (updated != null) Text(timeAgo(updated), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }
}
