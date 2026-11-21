import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../network/api_client.dart';
import '../utils/formatters.dart';

/// One building on RUPP Campus I (position + footprint from OpenStreetMap).
class CampusBuilding {
  CampusBuilding({
    required this.id,
    required this.code,
    required this.name,
    required this.position,
    required this.polygon,
    this.zone,
    this.zoneId,
    this.officialMapNo,
    required this.floorCount,
  });

  final String id;
  final String code;
  final String name;
  final LatLng position;
  final List<LatLng> polygon;
  final String? zone;
  final String? zoneId;
  final int? officialMapNo;
  final int floorCount;

  factory CampusBuilding.fromJson(Map<String, dynamic> j) => CampusBuilding(
        id: j['id'],
        code: j['code'] ?? '',
        name: j['name'] ?? '',
        position: LatLng(toDouble(j['latitude']), toDouble(j['longitude'])),
        polygon: _points(j['polygon']),
        zone: j['zone'],
        zoneId: j['zone_id'],
        officialMapNo: j['official_map_no'],
        floorCount: (j['floors'] as List? ?? []).length,
      );
}

class MapStore {
  MapStore({required this.id, required this.name, required this.position, this.building, this.locationNote, this.logoUrl, required this.isOpenNow, required this.rating});

  final String id;
  final String name;
  final LatLng position;
  final String? building;
  final String? locationNote;
  final String? logoUrl;
  final bool isOpenNow;
  final double rating;

  factory MapStore.fromJson(Map<String, dynamic> j) => MapStore(
        id: j['id'],
        name: j['name'] ?? '',
        position: LatLng(toDouble(j['latitude']), toDouble(j['longitude'])),
        building: j['building'],
        locationNote: j['location_note'],
        logoUrl: j['logo_url'],
        isOpenNow: j['is_open_now'] == true,
        rating: toDouble(j['rating_avg']),
      );
}

/// Campus outline + bounds used to keep every map inside RUPP Campus I.
class CampusMap {
  CampusMap({required this.name, required this.center, required this.bounds, required this.outline, required this.buildings, required this.stores, required this.attribution});

  final String name;
  final LatLng center;
  final LatLngBounds bounds;
  final List<LatLng> outline;
  final List<CampusBuilding> buildings;
  final List<MapStore> stores;
  final String attribution;

  CampusBuilding? building(String? id) {
    for (final b in buildings) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Bounds with a small margin so markers at the edge stay visible.
  LatLngBounds get paddedBounds => LatLngBounds(
        southwest: LatLng(bounds.southwest.latitude - 0.0006, bounds.southwest.longitude - 0.0006),
        northeast: LatLng(bounds.northeast.latitude + 0.0006, bounds.northeast.longitude + 0.0006),
      );

  factory CampusMap.fromJson(Map<String, dynamic> j) {
    final c = (j['campus'] as Map).cast<String, dynamic>();
    final b = (c['bounds'] as Map).cast<String, dynamic>();
    final center = c['center'] as List;
    return CampusMap(
      name: c['name'] ?? 'RUPP Campus I',
      center: LatLng(toDouble(center[0]), toDouble(center[1])),
      bounds: LatLngBounds(
        southwest: LatLng(toDouble(b['south']), toDouble(b['west'])),
        northeast: LatLng(toDouble(b['north']), toDouble(b['east'])),
      ),
      outline: _points(c['polygon']),
      buildings: (j['buildings'] as List).map((e) => CampusBuilding.fromJson((e as Map).cast())).toList(),
      stores: (j['stores'] as List).map((e) => MapStore.fromJson((e as Map).cast())).toList(),
      attribution: c['attribution'] ?? '© OpenStreetMap contributors',
    );
  }
}

List<LatLng> _points(dynamic raw) =>
    (raw as List? ?? []).map((p) => LatLng(toDouble((p as List)[0]), toDouble(p[1]))).toList();

/// Loads GET /campus/map once per app session.
class CampusMapRepository {
  CampusMapRepository(this._api);
  final ApiClient _api;
  Future<CampusMap>? _cache;

  Future<CampusMap> load({bool refresh = false}) {
    if (refresh || _cache == null) {
      final future = _api.get('/campus/map').then((r) => CampusMap.fromJson((r['data'] as Map).cast()));
      _cache = future;
      // Forget a failed load so the next screen retries.
      future.then((_) {}, onError: (_) {
        if (identical(_cache, future)) _cache = null;
      });
    }
    return _cache!;
  }
}

/// Whether a Google Maps key is configured (android/local.properties → MAPS_API_KEY).
class MapsConfig {
  static const _channel = MethodChannel('kh.edu.rupp.rupp_eat/config');
  static bool? _hasKey;

  static Future<bool> hasGoogleMapsKey() async {
    if (_hasKey != null) return _hasKey!;
    try {
      _hasKey = await _channel.invokeMethod<bool>('hasMapsKey') ?? false;
    } catch (_) {
      _hasKey = false;
    }
    return _hasKey!;
  }
}
