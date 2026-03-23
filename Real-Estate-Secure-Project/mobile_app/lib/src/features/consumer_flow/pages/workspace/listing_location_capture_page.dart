import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/map_config.dart';

class ConsumerListingLocationCaptureResult {
  const ConsumerListingLocationCaptureResult({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class ConsumerListingLocationCapturePage extends StatefulWidget {
  const ConsumerListingLocationCapturePage({
    super.key,
    required this.isLand,
    this.initialLatitude,
    this.initialLongitude,
    this.cityLabel,
  });

  final bool isLand;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? cityLabel;

  @override
  State<ConsumerListingLocationCapturePage> createState() =>
      _ConsumerListingLocationCapturePageState();
}

class _ConsumerListingLocationCapturePageState
    extends State<ConsumerListingLocationCapturePage> {
  static const LatLng _cameroonCenter = LatLng(5.9631, 12.7184);
  static const double _defaultZoom = 6.4;
  static const double _captureZoom = 17.2;
  static const double _maxAdjustmentDistanceMeters = 250;
  static const MarkerId _scanMarkerId = MarkerId('scan-point');
  static const MarkerId _selectedMarkerId = MarkerId('selected-point');

  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  LatLng? _scanPoint;
  LatLng? _selectedPoint;
  bool _locating = true;
  String? _locationIssue;
  bool _needsLocationSettings = false;
  bool _needsAppSettings = false;

  double? get _distanceFromScanMeters {
    final scanPoint = _scanPoint;
    final selectedPoint = _selectedPoint;
    if (scanPoint == null || selectedPoint == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      scanPoint.latitude,
      scanPoint.longitude,
      selectedPoint.latitude,
      selectedPoint.longitude,
    );
  }

  bool get _hasValidCapture {
    final distance = _distanceFromScanMeters;
    return _scanPoint != null &&
        _selectedPoint != null &&
        distance != null &&
        distance <= _maxAdjustmentDistanceMeters;
  }

  String get _pageTitle =>
      widget.isLand ? 'Capture parcel point' : 'Capture property point';

  String get _instructionTitle =>
      widget.isLand ? 'Stand on the parcel' : 'Stand at the property';

  String get _instructionBody => widget.isLand
      ? 'Scan your live location with Google Maps, then nudge the pin only if you need a small parcel adjustment.'
      : 'Scan your live location with Google Maps, then fine-tune the pin slightly if the entrance or structure needs a better point.';

  String get _saveLabel => 'Save point';

  String get _scanLabel => _scanPoint == null ? 'Scan now' : 'Rescan';

  String get _mapModeLabel =>
      _mapType == MapType.hybrid ? 'Satellite view' : 'Standard view';

  String get _distanceLabel {
    final distance = _distanceFromScanMeters;
    if (distance == null) {
      return 'Waiting';
    }
    return '${distance.toStringAsFixed(0)} m';
  }

  String get _pointSummary {
    final point = _selectedPoint;
    if (point == null) {
      return 'No point saved yet';
    }
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  String get _mapGuideTitle {
    if (_scanPoint == null) {
      return '1. Scan your live position';
    }
    if (_hasValidCapture) {
      return 'Ready to save';
    }
    return '2. Adjust with care';
  }

  String get _mapGuideBody {
    if (_scanPoint == null) {
      return widget.isLand
          ? 'Stand on the parcel and run a live scan to anchor the coordinates.'
          : 'Stand at the property and run a live scan to anchor the coordinates.';
    }
    if (_hasValidCapture) {
      return 'The saved point is inside the trusted range. You can store it now.';
    }
    return 'Keep the marker within 250 meters of the live scan so the location remains trustworthy.';
  }

  LatLng get _initialPoint {
    final latitude = widget.initialLatitude;
    final longitude = widget.initialLongitude;
    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }
    return _cameroonCenter;
  }

  @override
  void initState() {
    super.initState();
    _mapType = MapType.normal;
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureCurrentLocation(jumpToPoint: _selectedPoint == null);
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distance = _distanceFromScanMeters;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  ResCircleIconButton(
                    icon: ResIcons.back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pageTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.cityLabel?.trim().isNotEmpty == true
                              ? 'Live scan around ${widget.cityLabel}.'
                              : 'Live scan with Google Maps before saving the coordinates.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ResColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _initialPoint,
                                  zoom:
                                      widget.initialLatitude != null &&
                                          widget.initialLongitude != null
                                      ? 16.4
                                      : _defaultZoom,
                                ),
                                mapType: _mapType,
                                mapId: ResMapConfig.mapId,
                                mapToolbarEnabled: false,
                                zoomControlsEnabled: false,
                                buildingsEnabled: false,
                                indoorViewEnabled: false,
                                trafficEnabled: false,
                                fortyFiveDegreeImageryEnabled: false,
                                myLocationEnabled: false,
                                myLocationButtonEnabled: false,
                                compassEnabled: false,
                                onMapCreated: (controller) {
                                  _mapController = controller;
                                },
                                onTap: (point) {
                                  setState(() {
                                    _selectedPoint = point;
                                  });
                                },
                                markers: {
                                  if (_scanPoint != null)
                                    Marker(
                                      markerId: _scanMarkerId,
                                      position: _scanPoint!,
                                      zIndexInt: 1,
                                      icon: BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueAzure,
                                      ),
                                      infoWindow: const InfoWindow(
                                        title: 'Live scan',
                                      ),
                                    ),
                                  if (_selectedPoint != null)
                                    Marker(
                                      markerId: _selectedMarkerId,
                                      position: _selectedPoint!,
                                      zIndexInt: 2,
                                      draggable: true,
                                      icon: BitmapDescriptor.defaultMarkerWithHue(
                                        widget.isLand
                                            ? BitmapDescriptor.hueGreen
                                            : BitmapDescriptor.hueRed,
                                      ),
                                      onDragEnd: (point) {
                                        setState(() {
                                          _selectedPoint = point;
                                        });
                                      },
                                      infoWindow: InfoWindow(
                                        title: widget.isLand
                                            ? 'Parcel point'
                                            : 'Property point',
                                      ),
                                    ),
                                },
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 92,
                              child: ResSurfaceCard(
                                color: Colors.white.withValues(alpha: 0.96),
                                padding: const EdgeInsets.all(16),
                                radius: 24,
                                shadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(15, 23, 42, 0.12),
                                    blurRadius: 18,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _instructionTitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _instructionBody,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: ResColors.mutedForeground,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _CaptureChip(
                                          label: 'Stage',
                                          value: _mapGuideTitle,
                                        ),
                                        _CaptureChip(
                                          label: 'Distance',
                                          value: _distanceLabel,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Column(
                                children: [
                                  _MapActionButton(
                                    tooltip: _scanLabel,
                                    onPressed: _locating
                                        ? null
                                        : () => _captureCurrentLocation(),
                                    child: _locating
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.my_location_rounded),
                                  ),
                                  const SizedBox(height: 10),
                                  _MapActionButton(
                                    tooltip: _mapModeLabel,
                                    onPressed: _toggleMapType,
                                    child: Icon(
                                      _mapType == MapType.hybrid
                                          ? Icons.layers_clear_rounded
                                          : Icons.satellite_alt_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: ResSurfaceCard(
                                color: Colors.white.withValues(alpha: 0.95),
                                padding: const EdgeInsets.all(16),
                                radius: 24,
                                shadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(15, 23, 42, 0.12),
                                    blurRadius: 18,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _mapGuideTitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _mapGuideBody,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: ResColors.mutedForeground,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ResSurfaceCard(
                      color: ResColors.surfaceContainerLow,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CaptureMetricRow(
                            label: 'Saved coordinates',
                            value: _pointSummary,
                          ),
                          const SizedBox(height: 12),
                          _CaptureMetricRow(
                            label: 'Trusted range',
                            value: _distanceFromScanMeters == null
                                ? 'Scan and place the marker'
                                : 'Keep within 250 m of the live scan',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _locationIssue ??
                                (_hasValidCapture
                                    ? 'The point is ready to store.'
                                    : 'Keep the saved point within 250 meters of your live scan so the location stays trustworthy.'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color:
                                      _locationIssue == null &&
                                          (_hasValidCapture || distance == null)
                                      ? ResColors.mutedForeground
                                      : ResColors.warning,
                                ),
                          ),
                          if (_needsLocationSettings || _needsAppSettings) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (_needsLocationSettings)
                                  ResGhostButton(
                                    label: 'Location settings',
                                    icon: Icons.settings_outlined,
                                    onPressed: Geolocator.openLocationSettings,
                                  ),
                                if (_needsAppSettings)
                                  ResGhostButton(
                                    label: 'App settings',
                                    icon: Icons.lock_open_rounded,
                                    onPressed: Geolocator.openAppSettings,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ResOutlineButton(
                            label: _scanPoint == null ? 'Scan' : 'Rescan',
                            icon: Icons.my_location_rounded,
                            isPill: true,
                            onPressed: _locating
                                ? null
                                : () => _captureCurrentLocation(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ResPrimaryButton(
                            label: _saveLabel,
                            icon: ResIcons.check,
                            isPill: true,
                            onPressed: _hasValidCapture
                                ? () => Navigator.of(context).pop(
                                    ConsumerListingLocationCaptureResult(
                                      latitude: _selectedPoint!.latitude,
                                      longitude: _selectedPoint!.longitude,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureCurrentLocation({bool jumpToPoint = true}) async {
    setState(() {
      _locating = true;
      _locationIssue = null;
      _needsLocationSettings = false;
      _needsAppSettings = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationIssue =
              'Turn on device location services, then scan again at the land.';
          _needsLocationSettings = true;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _locationIssue =
              'Allow location access so we can capture the parcel from your live position.';
          _needsAppSettings = true;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationIssue =
              'Location access is blocked. Open app settings and allow it to continue.';
          _needsAppSettings = true;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _scanPoint = point;
        _selectedPoint = point;
      });
      if (jumpToPoint) {
        await _focusOnPoint(point);
      }
    } catch (_) {
      setState(() {
        _locationIssue =
            'We could not lock your current position. Move into open sky and try the scan again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Future<void> _focusOnPoint(LatLng point) async {
    await _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: _captureZoom),
      ),
    );
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.hybrid ? MapType.normal : MapType.hybrid;
    });
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.12),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: child),
    );
  }
}

class _CaptureChip extends StatelessWidget {
  const _CaptureChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ResColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: ResColors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CaptureMetricRow extends StatelessWidget {
  const _CaptureMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 122,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: ResColors.softForeground),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
