import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/locale_state.dart';
import '../../core/location_helper.dart';
import '../../core/map_config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/geocoding_api.dart';
import '../widgets/animations.dart';
import '../widgets/location_snackbars.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String? address;
  PickedLocation(this.lat, this.lng, {this.address});
}

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _map = MapController();
  final GeocodingApi _geo = GeocodingApi();
  late LatLng _picked;
  bool _locating = false;
  String? _address;
  bool _resolving = false;
  Timer? _debounce;
  int _lookupSeq = 0;

  @override
  void initState() {
    super.initState();
    _picked = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : MapConfig.irbidCenter;
    _lookupAddress();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onPinChanged(LatLng next) {
    setState(() {
      _picked = next;
      _address = null;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _lookupAddress);
  }

  Future<void> _lookupAddress() async {
    final mySeq = ++_lookupSeq;
    setState(() => _resolving = true);
    final isAr = context.read<LocaleState>().isArabic;
    final name = await _geo.reverseLookup(
      _picked.latitude,
      _picked.longitude,
      language: isAr ? 'ar,en' : 'en,ar',
    );
    if (!mounted || mySeq != _lookupSeq) return;
    setState(() {
      _address = name;
      _resolving = false;
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final next = await LocationHelper.locateClamped();
      if (next == null) {
        if (!mounted) return;
        showLocationPermissionDenied(context);
        return;
      }
      _map.move(next, MapConfig.locationZoom);
      _onPinChanged(next);
    } catch (_) {
      if (!mounted) return;
      showLocationUnavailable(context);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      PickedLocation(_picked.latitude, _picked.longitude, address: _address),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: MapConfig.initialZoom,
              minZoom: MapConfig.minZoom,
              maxZoom: MapConfig.maxZoom,
              cameraConstraint: MapConfig.cameraConstraint(),
              onTap: (_, latLng) => _onPinChanged(latLng),
            ),
            children: [
              MapConfig.tileLayer(),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on,
                        color: AppColors.danger, size: 44),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, color: AppColors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap the map to drop a pin, or use your GPS',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 195,
            child: Tooltip(
              message: context.t('submit.use_my_location'),
              child: PressableScale(
                onTap: _locating ? null : _useMyLocation,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10),
                    ],
                  ),
                  child: _locating
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.blue),
                        )
                      : const Icon(Icons.my_location, color: AppColors.blue),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selected location',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _resolving
                              ? 'Looking up address…'
                              : (_address ?? context.t('map.unnamed_location')),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_resolving)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.blue),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PressableScale(
                    onTap: _confirm,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.blue.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('Confirm Location',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    MapConfig.attribution,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
