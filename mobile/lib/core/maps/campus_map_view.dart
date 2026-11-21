import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_theme.dart';
import 'campus_map_data.dart';

/// A pin on a campus map.
class CampusPin {
  const CampusPin({required this.id, required this.position, required this.title, this.subtitle, this.kind = PinKind.store, this.onTap});
  final String id;
  final LatLng position;
  final String title;
  final String? subtitle;
  final PinKind kind;
  final VoidCallback? onTap;
}

enum PinKind { store, destination, driver, me }

extension on PinKind {
  double get hue => switch (this) {
        PinKind.store => BitmapDescriptor.hueOrange,
        PinKind.destination => BitmapDescriptor.hueGreen,
        PinKind.driver => BitmapDescriptor.hueAzure,
        PinKind.me => BitmapDescriptor.hueViolet,
      };
  Color get color => switch (this) {
        PinKind.store => const Color(0xFFE08A00),
        PinKind.destination => AppColors.accent,
        PinKind.driver => const Color(0xFF1565C0),
        PinKind.me => const Color(0xFF6A1B9A),
      };
  IconData get icon => switch (this) {
        PinKind.store => Icons.storefront_rounded,
        PinKind.destination => Icons.meeting_room_rounded,
        PinKind.driver => Icons.delivery_dining_rounded,
        PinKind.me => Icons.my_location_rounded,
      };
}

/// Google Map locked to RUPP Campus I: camera bounds = campus outline, zoom 16–20,
/// with the real building footprints drawn on top. Falls back to a drawn campus
/// plan (same real coordinates) when no Google Maps key is configured.
class CampusMapView extends StatefulWidget {
  const CampusMapView({
    super.key,
    required this.campus,
    this.pins = const [],
    this.route = const [],
    this.selectedBuildingId,
    this.highlightBuildingIds = const {},
    this.onBuildingTap,
    this.showMyLocation = false,
    this.fitPins = false,
    this.compact = false,
  });

  final CampusMap campus;
  final List<CampusPin> pins;
  final List<LatLng> route;
  final String? selectedBuildingId;
  final Set<String> highlightBuildingIds;
  final ValueChanged<CampusBuilding>? onBuildingTap;
  final bool showMyLocation;
  final bool fitPins;
  final bool compact;

  @override
  State<CampusMapView> createState() => CampusMapViewState();
}

class CampusMapViewState extends State<CampusMapView> {
  bool? _google;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    MapsConfig.hasGoogleMapsKey().then((v) {
      if (mounted) setState(() => _google = v);
    });
  }

  @override
  void didUpdateWidget(covariant CampusMapView old) {
    super.didUpdateWidget(old);
    if (widget.fitPins && old.pins.length != widget.pins.length) _fit();
  }

  /// Smoothly centre on a point (used by store lists under the map).
  Future<void> focus(LatLng target, {double zoom = 18.5}) async {
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  void _fit() {
    final c = _controller;
    if (c == null) return;
    final pts = widget.pins.map((p) => p.position).toList();
    if (pts.length < 2) return;
    final b = LatLngBounds(
      southwest: LatLng(pts.map((p) => p.latitude).reduce(math.min), pts.map((p) => p.longitude).reduce(math.min)),
      northeast: LatLng(pts.map((p) => p.latitude).reduce(math.max), pts.map((p) => p.longitude).reduce(math.max)),
    );
    c.animateCamera(CameraUpdate.newLatLngBounds(b, 60));
  }

  @override
  Widget build(BuildContext context) {
    if (_google == null) return const ColoredBox(color: AppColors.primaryLight);
    return Stack(children: [
      Positioned.fill(child: _google! ? _googleMap() : _FallbackCampusMap(view: widget)),
      Positioned(
        left: 8,
        bottom: 4,
        child: Text(
          _google! ? '© OpenStreetMap contributors (buildings)' : '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 9, color: Colors.black.withValues(alpha: 0.55)),
        ),
      ),
      if (!_google! && !widget.compact)
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(10)),
            child: const Text(
              'Campus plan view · add MAPS_API_KEY in android/local.properties for the Google map',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ),
    ]);
  }

  Widget _googleMap() {
    final campus = widget.campus;
    final polygons = <Polygon>{
      Polygon(
        polygonId: const PolygonId('campus'),
        points: campus.outline,
        strokeColor: AppColors.primary,
        strokeWidth: 3,
        fillColor: AppColors.primary.withValues(alpha: 0.04),
      ),
      for (final b in campus.buildings)
        if (b.polygon.length >= 3)
          Polygon(
            polygonId: PolygonId(b.id),
            points: b.polygon,
            consumeTapEvents: widget.onBuildingTap != null,
            onTap: widget.onBuildingTap == null ? null : () => widget.onBuildingTap!(b),
            strokeWidth: b.id == widget.selectedBuildingId ? 3 : 1,
            strokeColor: b.id == widget.selectedBuildingId ? AppColors.gold : AppColors.primary,
            fillColor: b.id == widget.selectedBuildingId
                ? AppColors.gold.withValues(alpha: 0.55)
                : widget.highlightBuildingIds.contains(b.id)
                    ? AppColors.accent.withValues(alpha: 0.35)
                    : AppColors.primary.withValues(alpha: 0.16),
            zIndex: 1,
          ),
    };
    final markers = <Marker>{
      for (final p in widget.pins)
        Marker(
          markerId: MarkerId(p.id),
          position: p.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(p.kind.hue),
          infoWindow: InfoWindow(title: p.title, snippet: p.subtitle, onTap: p.onTap),
          zIndexInt: p.kind == PinKind.driver ? 3 : 2,
        ),
    };
    final polylines = <Polyline>{
      if (widget.route.length >= 2)
        Polyline(
          polylineId: const PolylineId('route'),
          points: widget.route,
          color: AppColors.primary,
          width: 5,
          patterns: [PatternItem.dash(18), PatternItem.gap(10)],
        ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: campus.center, zoom: widget.compact ? 16.6 : 17.2),
      cameraTargetBounds: CameraTargetBounds(campus.paddedBounds),
      minMaxZoomPreference: const MinMaxZoomPreference(16, 20.5),
      polygons: polygons,
      markers: markers,
      polylines: polylines,
      myLocationEnabled: widget.showMyLocation,
      myLocationButtonEnabled: widget.showMyLocation && !widget.compact,
      mapToolbarEnabled: false,
      zoomControlsEnabled: !widget.compact,
      buildingsEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        if (widget.fitPins) Future.delayed(const Duration(milliseconds: 300), _fit);
      },
    );
  }
}

/// Drawn campus plan used when Google Maps has no API key: same real coordinates
/// (campus outline, building footprints, pins, route), tap-to-select buildings.
class _FallbackCampusMap extends StatelessWidget {
  const _FallbackCampusMap({required this.view});
  final CampusMapView view;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final b = view.campus.bounds;
      const m = 0.00015; // ~15 m margin around the campus outline
      final proj = _Projection(
        LatLngBounds(southwest: LatLng(b.southwest.latitude - m, b.southwest.longitude - m), northeast: LatLng(b.northeast.latitude + m, b.northeast.longitude + m)),
        box.biggest,
      );
      // Pinch to zoom / drag, limited to the campus.
      return InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: _plan(context, box, proj),
      );
    });
  }

  Widget _plan(BuildContext context, BoxConstraints box, _Projection proj) {
    {
      return GestureDetector(
        onTapUp: (d) {
          // Pins first, then buildings
          for (final p in view.pins.reversed) {
            if ((proj.toScreen(p.position) - d.localPosition).distance < 22) {
              _showPin(context, p);
              return;
            }
          }
          if (view.onBuildingTap == null) return;
          final ll = proj.toLatLng(d.localPosition);
          for (final b in view.campus.buildings) {
            if (_inside(ll, b.polygon)) {
              view.onBuildingTap!(b);
              return;
            }
          }
        },
        child: Stack(children: [
          CustomPaint(size: box.biggest, painter: _CampusPainter(view, proj)),
          for (final p in view.pins)
            Positioned(
              left: proj.toScreen(p.position).dx - 15,
              top: proj.toScreen(p.position).dy - 34,
              child: IgnorePointer(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: p.kind.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                    child: Icon(p.kind.icon, size: 16, color: Colors.white),
                  ),
                  Container(width: 2, height: 4, color: p.kind.color),
                ]),
              ),
            ),
        ]),
      );
    }
  }

  void _showPin(BuildContext context, CampusPin p) {
    if (p.onTap != null) {
      p.onTap!();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text([p.title, p.subtitle].whereType<String>().join(' · '))));
  }
}

class _Projection {
  _Projection(this.bounds, this.size) {
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = (bounds.northeast.longitude - bounds.southwest.longitude) * math.cos(bounds.southwest.latitude * math.pi / 180);
    scale = math.min(size.width / lngSpan, size.height / latSpan);
    offset = Offset((size.width - lngSpan * scale) / 2, (size.height - latSpan * scale) / 2);
  }
  final LatLngBounds bounds;
  final Size size;
  late final double scale;
  late final Offset offset;
  double get _cos => math.cos(bounds.southwest.latitude * math.pi / 180);

  Offset toScreen(LatLng p) => Offset(
        offset.dx + (p.longitude - bounds.southwest.longitude) * _cos * scale,
        offset.dy + (bounds.northeast.latitude - p.latitude) * scale,
      );

  LatLng toLatLng(Offset o) => LatLng(
        bounds.northeast.latitude - (o.dy - offset.dy) / scale,
        bounds.southwest.longitude + (o.dx - offset.dx) / (scale * _cos),
      );
}

bool _inside(LatLng p, List<LatLng> poly) {
  var c = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
        p.longitude < (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude) {
      c = !c;
    }
  }
  return c;
}

class _CampusPainter extends CustomPainter {
  _CampusPainter(this.view, this.proj);
  final CampusMapView view;
  final _Projection proj;

  Path _path(List<LatLng> pts) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = proj.toScreen(pts[i]);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEFEDE6));
    final outline = _path(view.campus.outline);
    canvas.drawPath(outline, Paint()..color = const Color(0xFFDDEBDD));
    canvas.drawPath(outline, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.primary);

    for (final b in view.campus.buildings) {
      if (b.polygon.length < 3) continue;
      final selected = b.id == view.selectedBuildingId;
      final hl = view.highlightBuildingIds.contains(b.id);
      final p = _path(b.polygon);
      canvas.drawPath(p, Paint()..color = selected ? AppColors.gold : hl ? AppColors.accent.withValues(alpha: 0.55) : const Color(0xFFB9C9BE));
      canvas.drawPath(p, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1
        ..color = AppColors.primary);
      if (!view.compact) {
        final tp = TextPainter(
          text: TextSpan(text: b.code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
          textDirection: TextDirection.ltr,
        )..layout();
        final c = proj.toScreen(b.position);
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }

    if (view.route.length >= 2) {
      final paint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < view.route.length - 1; i++) {
        final a = proj.toScreen(view.route[i]), b = proj.toScreen(view.route[i + 1]);
        final len = (b - a).distance;
        final dir = (b - a) / len;
        for (double t = 0; t < len; t += 16) {
          canvas.drawLine(a + dir * t, a + dir * math.min(t + 9, len), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CampusPainter old) => true;
}

/// Straight-line distance in metres (campus distances are short; no Directions API needed).
double metresBetween(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.latitude * math.pi / 180) * math.cos(b.latitude * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}
