// MapConfig — single shared source of truth for the Irbid-only map used
// by both the report location picker and the explore map.
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

abstract final class MapConfig {
  /// Center of Irbid city.
  static const LatLng irbidCenter = LatLng(32.5556, 35.8500);

  /// Bounding box covering Irbid city and its immediate surroundings.
  static final LatLngBounds irbidBounds = LatLngBounds(
    const LatLng(32.4200, 35.6800), // southWest
    const LatLng(32.6800, 36.0200), // northEast
  );

  static const double minZoom = 11;
  static const double maxZoom = 18;
  static const double initialZoom = 13;

  /// Esri World Street Map tiles (free to use with attribution).
  static const String esriStreetUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/'
      'World_Street_Map/MapServer/tile/{z}/{y}/{x}';

  /// OpenStreetMap tiles, used automatically when Esri is unavailable.
  static const String osmStreetUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String attribution =
      'Esri, Maxar, Earthstar Geographics, and the GIS User Community · '
      '© OpenStreetMap contributors';

  /// A [TileLayer] rendering Esri street tiles with an OSM fallback.
  static TileLayer tileLayer() => TileLayer(
        urlTemplate: esriStreetUrl,
        fallbackUrl: osmStreetUrl,
        maxZoom: maxZoom,
        maxNativeZoom: 19,
        userAgentPackageName: 'com.balaghjo.app',
      );

  /// Keeps the whole map viewport inside the Irbid bounds.
  static CameraConstraint cameraConstraint() =>
      CameraConstraint.contain(bounds: irbidBounds);

  /// Clamps a coordinate into the Irbid bounds so pins never land off-screen.
  static LatLng clampToBounds(LatLng p) => LatLng(
        p.latitude.clamp(irbidBounds.south, irbidBounds.north),
        p.longitude.clamp(irbidBounds.west, irbidBounds.east),
      );
}
