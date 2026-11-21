import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/maps/campus_map_data.dart';
import '../../../core/maps/campus_map_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../models/delivery.dart';
import '../services/location_reporter.dart';

/// Driver map: my position, the store and the destination building inside Campus I,
/// with a route line and an "Open in Google Maps" button for turn-by-turn directions.
class DriverNavigationMap extends StatefulWidget {
  const DriverNavigationMap({super.key, required this.delivery, this.vehicleType = 'motorbike'});
  final Delivery delivery;
  final String vehicleType;

  @override
  State<DriverNavigationMap> createState() => _DriverNavigationMapState();
}

class _DriverNavigationMapState extends State<DriverNavigationMap> {
  CampusMap? _campus;

  @override
  void initState() {
    super.initState();
    context.read<CampusMapRepository>().load().then((c) {
      if (mounted) setState(() => _campus = c);
    }).catchError((_) {});
  }

  Future<void> _openGoogleMaps(LatLng target) async {
    final mode = switch (widget.vehicleType) { 'walking' => 'walking', 'bicycle' => 'bicycling', _ => 'two-wheeler' };
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}&travelmode=$mode');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      showSnack(context, 'Cannot open Google Maps', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final reporter = context.watch<DriverLocationReporter>();
    final me = reporter.last == null ? null : LatLng(reporter.last!.latitude, reporter.last!.longitude);
    final store = d.storeLat == null ? null : LatLng(d.storeLat!, d.storeLng!);
    final dest = d.location?.latitude == null ? null : LatLng(d.location!.latitude!, d.location!.longitude!);
    final target = d.headingToStore ? store : dest;

    if (_campus == null) return const SizedBox(height: 240, child: Card(child: Center(child: CircularProgressIndicator())));

    final route = <LatLng>[
      ?me,
      if (d.headingToStore) ?store,
      ?dest,
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
          height: 250,
          child: CampusMapView(
            campus: _campus!,
            compact: true,
            fitPins: true,
            route: route.length >= 2 ? route : const [],
            pins: [
              if (store != null) CampusPin(id: 'store', position: store, title: d.storeName, subtitle: 'Pick up here'),
              if (dest != null) CampusPin(id: 'dest', position: dest, kind: PinKind.destination, title: d.location!.building, subtitle: '${d.location!.floor} · ${d.location!.room}'),
              if (me != null) CampusPin(id: 'me', position: me, kind: PinKind.driver, title: 'You'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.headingToStore ? 'Go to ${d.storeName}' : 'Go to ${d.location?.building ?? 'customer'}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  reporter.problem ??
                      (me != null && target != null ? '${metresBetween(me, target).round()} m away (straight line)' : 'Waiting for GPS…'),
                  style: TextStyle(fontSize: 12.5, color: reporter.problem != null ? AppColors.danger : AppColors.textMuted),
                ),
              ]),
            ),
            if (target != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: () => _openGoogleMaps(target),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Google Maps'),
              ),
          ]),
        ),
      ]),
    );
  }
}
