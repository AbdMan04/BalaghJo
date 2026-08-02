class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://balaghjo.onrender.com',
  );

  // Photos are stored either as full URLs (Cloudinary) or relative API
  // paths (local uploads dir); resolve both to a displayable URL.
  static String imageUrl(String url) =>
      url.startsWith('http') ? url : '$apiBaseUrl$url';
}
