class AppConfig {
  // Use 10.0.2.2 for Android emulator → host machine.
  // Replace with your LAN IP for a real device, or http://localhost:4000 for iOS sim/web.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.100.11:4000',
  );
}
