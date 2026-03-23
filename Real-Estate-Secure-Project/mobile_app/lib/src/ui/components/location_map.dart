import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app_icons.dart';
import '../brand.dart';
import '../map_config.dart';

class ResStaticLocationMap extends StatelessWidget {
  const ResStaticLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.height = 188,
  });

  final double? latitude;
  final double? longitude;
  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      return _MapUnavailable(height: height);
    }

    final point = LatLng(lat, lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: point, zoom: 15),
                mapId: ResMapConfig.mapId,
                markers: {
                  Marker(
                    markerId: const MarkerId('property-location'),
                    position: point,
                    infoWindow: InfoWindow(title: title),
                  ),
                },
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                liteModeEnabled: true,
              ),
            ),
            const Positioned(top: 14, right: 14, child: _MapBadge()),
          ],
        ),
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCE6F6), Color(0xFFF2F6FB)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              ResIcons.location,
              color: ResColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Map preview unavailable',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Exact coordinates will appear here when the property has a publishable map location.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(16, 24, 40, 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'Map',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ResColors.foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
