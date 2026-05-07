import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingApi {
  static const _base = 'https://nominatim.openstreetmap.org/reverse';

  Future<String?> reverseLookup(double lat, double lng) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'format': 'json',
      'lat': lat.toString(),
      'lon': lng.toString(),
      'zoom': '18',
      'addressdetails': '1',
    });
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'com.balaghjo.app/1.0',
        'Accept-Language': 'en,ar',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200 || res.body.isEmpty) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = (data['address'] as Map?)?.cast<String, dynamic>() ?? const {};

      final street = addr['road'] ?? addr['pedestrian'] ?? addr['footway'];
      final area = addr['suburb'] ??
          addr['neighbourhood'] ??
          addr['quarter'] ??
          addr['village'] ??
          addr['town'] ??
          addr['city'];

      if (street != null && area != null) return '$street, $area';
      if (street != null) return street as String;
      if (area != null) return area as String;
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
