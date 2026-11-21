/// Runtime configuration.
///
/// The Android emulator reaches the host PC's `localhost` through 10.0.2.2.
/// For a real phone on the same Wi-Fi, run with your PC's LAN IP:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// How often live screens (order tracking, driver requests) refresh.
  static const Duration pollInterval = Duration(seconds: 10);
}
