import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/driver_repository.dart';

/// Sends the driver's real GPS position to the API every few seconds while they are
/// online (app in the foreground). Customers see it on their live tracking map.
class DriverLocationReporter extends ChangeNotifier {
  DriverLocationReporter(this._repo);
  final DriverRepository _repo;

  StreamSubscription<Position>? _sub;
  Timer? _timer;
  Position? last;
  String? problem; // permission / GPS-off message for the UI
  bool get running => _sub != null;

  Future<void> setOnline(bool online) => online ? start() : stop();

  Future<void> start() async {
    if (running) return;
    problem = await _ensurePermission();
    notifyListeners();
    if (problem != null) return;

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((p) {
      final first = last == null;
      last = p;
      problem = null;
      notifyListeners();
      if (first) _send(); // share the first fix immediately
    }, onError: (e) {
      problem = 'Location unavailable: $e';
      notifyListeners();
    });
    // The stream delivers the first fix too (one request = at most one system location prompt).
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _send());
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  Future<void> _send() async {
    final p = last;
    if (p == null) return;
    try {
      await _repo.sendLocation(p.latitude, p.longitude, p.heading >= 0 ? p.heading : null);
    } catch (e) {
      debugPrint('Location upload failed: $e');
    }
  }

  Future<String?> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return 'Turn on location (GPS) so customers can follow your delivery.';
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) return 'Allow location access so customers can follow your delivery.';
    if (perm == LocationPermission.deniedForever) return 'Location is blocked for RUPP Eat. Enable it in Android Settings → Apps → RUPP Eat.';
    return null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
