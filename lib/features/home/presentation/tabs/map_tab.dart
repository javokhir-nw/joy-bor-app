import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../listings/presentation/listing_detail_screen.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;
  bool _locationGranted = false;
  double _zoom = 12;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _requestLocationPermission();
    await _loadListings();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      final result = await Permission.locationWhenInUse.request();
      if (mounted) {
        setState(() => _locationGranted = result.isGranted);
      }
    } else if (status.isGranted) {
      if (mounted) setState(() => _locationGranted = true);
    } else if (status.isPermanentlyDenied) {
      if (mounted) setState(() => _locationGranted = false);
    }
  }

  Future<void> _loadListings() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('listings')
          .where('isActive', isEqualTo: true)
          .get();

      _listings = snap.docs
          .where((d) => d['location'] != null)
          .map((d) => d.data())
          .toList();
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
    await _updateMarkers();
  }

  Future<void> _updateMarkers() async {
    final clusters = _cluster(_listings, _zoom);
    final markers = <Marker>{};
    for (final c in clusters) {
      final isMulti = (c['items'] as List).length > 1;
      final pos = c['position'] as LatLng;
      final label = isMulti
          ? '${(c['items'] as List).length} ta'
          : _priceLabel(c['items'][0]);
      final icon = await _buildIcon(label, isMulti);
      markers.add(Marker(
        markerId: MarkerId('${pos.latitude}_${pos.longitude}'),
        position: pos,
        icon: icon,
        onTap: () {
          if (!isMulti) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ListingDetailScreen(data: c['items'][0]),
              ),
            );
          } else {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(pos, _zoom + 2),
            );
          }
        },
      ));
    }
    if (mounted) setState(() => _markers = markers);
  }

  String _priceLabel(Map<String, dynamic> d) {
    final p = (d['price'] ?? 0) as num;
    final c = d['currency'] ?? 'USD';
    return p >= 1000 ? '${(p / 1000).toStringAsFixed(0)}K $c' : '$p $c';
  }

  Future<BitmapDescriptor> _buildIcon(String label, bool isMulti) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const w = 120.0, h = 44.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h), const Radius.circular(22)),
      Paint()
        ..color = isMulti ? AppColors.accent : AppColors.primary,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);
    tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));
    final img = await recorder
        .endRecording()
        .toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    // fromBytes → bytes (deprecated fix)
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  List<Map<String, dynamic>> _cluster(
      List<Map<String, dynamic>> items, double zoom) {
    final radius = 0.05 / pow(2, zoom - 12);
    final used = List.filled(items.length, false);
    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < items.length; i++) {
      if (used[i]) continue;
      final loc = items[i]['location'] as GeoPoint;
      final group = [items[i]];
      used[i] = true;

      for (int j = i + 1; j < items.length; j++) {
        if (used[j]) continue;
        final loc2 = items[j]['location'] as GeoPoint;
        final dist = _dist(
            loc.latitude, loc.longitude, loc2.latitude, loc2.longitude);
        if (dist < radius) {
          group.add(items[j]);
          used[j] = true;
        }
      }

      double lat = 0, lng = 0;
      for (final g in group) {
        final l = g['location'] as GeoPoint;
        lat += l.latitude;
        lng += l.longitude;
      }
      result.add({
        'items': group,
        'position': LatLng(lat / group.length, lng / group.length),
      });
    }
    return result;
  }

  double _dist(double lat1, double lng1, double lat2, double lng2) {
    return sqrt(pow(lat1 - lat2, 2) + pow(lng1 - lng2, 2));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
              target: LatLng(41.2995, 69.2401), zoom: 12),
          markers: _markers,
          myLocationEnabled: _locationGranted,
          myLocationButtonEnabled: _locationGranted,
          onMapCreated: (c) => _mapController = c,
          onCameraIdle: () async {
            final zoom = await _mapController?.getZoomLevel() ?? 12;
            _zoom = zoom;
            await _updateMarkers();
          },
        ),

        // Ruxsat berilmagan holda pastda banner ko'rsatish
        if (!_locationGranted)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off_outlined,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Joylashuvga ruxsat berilmagan',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 32),
                    ),
                    child: const Text('Ruxsat berish',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
