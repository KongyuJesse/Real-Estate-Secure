import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/map_config.dart';
import '../../../../ui/components/navigation.dart';
import '../../../../ui/components/property_media.dart';

class ConsumerMapTab extends StatefulWidget {
  const ConsumerMapTab({
    super.key,
    required this.controller,
    required this.onOpenProperty,
  });

  final ConsumerController controller;
  final ValueChanged<String> onOpenProperty;

  @override
  State<ConsumerMapTab> createState() => _ConsumerMapTabState();
}

class _ConsumerMapTabState extends State<ConsumerMapTab> {
  late final TextEditingController _searchController;
  GoogleMapController? _mapController;
  String? _selectedPointId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
    _selectedPointId = widget.controller.mapPoints.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(covariant ConsumerMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.controller.searchQuery) {
      _searchController.text = widget.controller.searchQuery;
    }
    if (_visiblePoints.isNotEmpty &&
        !_visiblePoints.any((item) => item.id == _selectedPointId)) {
      _selectedPointId = _visiblePoints.first.id;
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ConsumerPropertyMapPoint> get _visiblePoints {
    final query = widget.controller.searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.controller.mapPoints;
    }
    return widget.controller.mapPoints
        .where((point) {
          return point.title.toLowerCase().contains(query) ||
              point.city.toLowerCase().contains(query) ||
              point.region.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final points = _visiblePoints;
    final selected =
        points.where((item) => item.id == _selectedPointId).firstOrNull ??
        points.firstOrNull;
    return Stack(
      children: [
        Positioned.fill(
          child: points.isEmpty
              ? const DecoratedBox(
                  decoration: BoxDecoration(color: ResColors.muted),
                )
              : ClipRRect(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _initialTarget(points),
                      zoom: points.length == 1 ? 14.2 : 6.7,
                    ),
                    mapId: ResMapConfig.mapId,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    markers: _buildMarkers(points),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _fitToVisiblePoints();
                    },
                  ),
                ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ResColors.background.withValues(alpha: 0.92),
                  Colors.transparent,
                  ResColors.background.withValues(alpha: 0.98),
                ],
                stops: const [0, 0.28, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                ResSearchBar(
                  controller: _searchController,
                  hintText: 'Search city or region',
                  trailing: IconButton(
                    onPressed: _showFilterSheet,
                    icon: const Icon(ResIcons.filter, color: ResColors.primary),
                  ),
                  onChanged: (value) {
                    widget.controller.updateSearch(value);
                    if (mounted) {
                      setState(() {
                        _selectedPointId = _visiblePoints.firstOrNull?.id;
                      });
                    }
                    _fitToVisiblePoints();
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Houses',
                        selected:
                            widget.controller.propertyTypeFilter == 'house',
                        onTap: () {
                          widget.controller.applyFilter(propertyType: 'house');
                          setState(() {});
                          _fitToVisiblePoints();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Land',
                        selected:
                            widget.controller.propertyTypeFilter == 'land',
                        onTap: () {
                          widget.controller.applyFilter(propertyType: 'land');
                          setState(() {});
                          _fitToVisiblePoints();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Sale',
                        selected: widget.controller.listingTypeFilter == 'sale',
                        onTap: () {
                          widget.controller.applyFilter(listingType: 'sale');
                          setState(() {});
                          _fitToVisiblePoints();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Rent',
                        selected: widget.controller.listingTypeFilter == 'rent',
                        onTap: () {
                          widget.controller.applyFilter(listingType: 'rent');
                          setState(() {});
                          _fitToVisiblePoints();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Clear',
                        selected:
                            widget.controller.listingTypeFilter == null &&
                            widget.controller.propertyTypeFilter == null,
                        onTap: () {
                          widget.controller.clearFilters();
                          setState(() {});
                          _fitToVisiblePoints();
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 156,
          child: Column(
            children: [
              _MapControl(
                icon: Icons.add_rounded,
                onTap: () =>
                    _mapController?.animateCamera(CameraUpdate.zoomIn()),
              ),
              const SizedBox(height: 10),
              _MapControl(
                icon: Icons.remove_rounded,
                onTap: () =>
                    _mapController?.animateCamera(CameraUpdate.zoomOut()),
              ),
              const SizedBox(height: 12),
              _MapControl(
                icon: Icons.gps_fixed_rounded,
                accent: true,
                onTap: _fitToVisiblePoints,
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: selected == null ? 128 : 194,
          child: Center(
            child: FilledButton.icon(
              onPressed: () => widget.controller.setTab(ConsumerTab.listings),
              style: FilledButton.styleFrom(
                backgroundColor: ResColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.view_list_rounded, size: 18),
              label: const Text('Listings'),
            ),
          ),
        ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 92,
            child: GestureDetector(
              onTap: () => widget.onOpenProperty(selected.id),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ResColors.card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: ResShadows.card,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: ResPropertyMedia(
                        propertyType: _typeForPoint(selected.title),
                        title: selected.title,
                        borderRadius: BorderRadius.circular(20),
                        showLabel: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selected.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                ResIcons.location,
                                size: 16,
                                color: ResColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${selected.city}, ${selected.region}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: ResColors.mutedForeground,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatXaf(selected.price),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: ResColors.primary),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: ResColors.muted,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: ResColors.foreground,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Set<Marker> _buildMarkers(List<ConsumerPropertyMapPoint> points) {
    return points.map((point) {
      final isSelected = point.id == _selectedPointId;
      return Marker(
        markerId: MarkerId(point.id),
        position: LatLng(point.latitude, point.longitude),
        infoWindow: InfoWindow(
          title: point.title,
          snippet: '${point.city}, ${point.region}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRose,
        ),
        onTap: () {
          setState(() => _selectedPointId = point.id);
        },
      );
    }).toSet();
  }

  Future<void> _fitToVisiblePoints() async {
    final controller = _mapController;
    final points = _visiblePoints;
    if (controller == null || points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(points.first.latitude, points.first.longitude),
            zoom: 14.2,
          ),
        ),
      );
      return;
    }
    final bounds = _boundsFromPoints(points);
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Future<void> _showFilterSheet() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Map filters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SheetActionChip(
                    label: 'All properties',
                    onTap: () {
                      widget.controller.clearFilters();
                      Navigator.of(context).pop();
                      setState(() {});
                      _fitToVisiblePoints();
                    },
                  ),
                  _SheetActionChip(
                    label: 'Houses',
                    onTap: () {
                      widget.controller.applyFilter(propertyType: 'house');
                      Navigator.of(context).pop();
                      setState(() {});
                      _fitToVisiblePoints();
                    },
                  ),
                  _SheetActionChip(
                    label: 'Land',
                    onTap: () {
                      widget.controller.applyFilter(propertyType: 'land');
                      Navigator.of(context).pop();
                      setState(() {});
                      _fitToVisiblePoints();
                    },
                  ),
                  _SheetActionChip(
                    label: 'Sale only',
                    onTap: () {
                      widget.controller.applyFilter(listingType: 'sale');
                      Navigator.of(context).pop();
                      setState(() {});
                      _fitToVisiblePoints();
                    },
                  ),
                  _SheetActionChip(
                    label: 'Rent only',
                    onTap: () {
                      widget.controller.applyFilter(listingType: 'rent');
                      Navigator.of(context).pop();
                      setState(() {});
                      _fitToVisiblePoints();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  LatLngBounds _boundsFromPoints(List<ConsumerPropertyMapPoint> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    if (minLat == maxLat) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if (minLng == maxLng) {
      minLng -= 0.01;
      maxLng += 0.01;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  LatLng _initialTarget(List<ConsumerPropertyMapPoint> points) {
    if (points.isEmpty) {
      return const LatLng(3.848, 11.502);
    }
    final latitude =
        points.map((item) => item.latitude).reduce((a, b) => a + b) /
        points.length;
    final longitude =
        points.map((item) => item.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(latitude, longitude);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? ResColors.primary : ResColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? ResColors.primary : ResColors.border,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? Colors.white : ResColors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: accent ? ResColors.primary : ResColors.foreground,
          ),
        ),
      ),
    );
  }
}

class _SheetActionChip extends StatelessWidget {
  const _SheetActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: const Icon(ResIcons.filter, size: 16),
    );
  }
}

String _typeForPoint(String title) {
  final lowered = title.toLowerCase();
  if (lowered.contains('land')) {
    return 'land';
  }
  if (lowered.contains('apartment')) {
    return 'apartment';
  }
  if (lowered.contains('commercial')) {
    return 'commercial';
  }
  return 'house';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
