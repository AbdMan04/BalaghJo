import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingApi {
  static const _base = 'https://nominatim.openstreetmap.org/reverse';

  Future<String?> reverseLookup(
    double lat,
    double lng, {
    String language = 'en,ar',
  }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'format': 'json',
      'lat': lat.toString(),
      'lon': lng.toString(),
      'zoom': '18',
      'addressdetails': '1',
      'namedetails': '1',
      'countrycodes': 'jo',
    });
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'com.balaghjo.app/1.0',
        'Accept-Language': language,
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200 || res.body.isEmpty) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = (data['address'] as Map?)?.cast<String, dynamic>() ?? const {};

      String? street;
      for (final key in ['road', 'pedestrian', 'footway', 'living_street', 'service']) {
        final v = addr[key];
        if (v is String && v.isNotEmpty) {
          street = v;
          break;
        }
      }
      final streetNo = addr['house_number'];
      final district = addr['neighbourhood'] ??
          addr['quarter'] ??
          addr['suburb'] ??
          addr['hamlet'];
      final area = addr['town'] ??
          addr['city'] ??
          addr['village'] ??
          addr['county'] ??
          addr['state'];

      final parts = <String>[
        if (streetNo is String && streetNo.isNotEmpty) streetNo,
        if (street != null) street,
      ];
      final line = parts.isNotEmpty ? parts.join(' ') : null;

      if (line != null && district != null) return '$line, $district';
      if (line != null && area != null) return '$line, $area';
      if (line != null) return line;
      if (district != null && area != null) return '$district, $area';
      if (district != null) return district as String;
      if (area != null) return area as String;
      final name = data['name'];
      if (name is String && name.isNotEmpty) return name;
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
