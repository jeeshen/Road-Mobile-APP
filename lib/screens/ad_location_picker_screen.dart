import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

class AdLocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const AdLocationPickerScreen({super.key, this.initialLocation});

  @override
  State<AdLocationPickerScreen> createState() => _AdLocationPickerScreenState();
}

class _AdLocationPickerScreenState extends State<AdLocationPickerScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  LatLng? _selectedLocation;
  LatLng _mapCenter = const LatLng(3.1390, 101.6869); // Kuala Lumpur default
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (mounted && position != null) {
        final newCenter = LatLng(position.latitude, position.longitude);
        setState(() {
          _mapCenter = newCenter;
          if (_selectedLocation == null) {
            _selectedLocation = newCenter;
          }
          _isLoadingLocation = false;
        });
        
        // Move map to current location
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _mapController.move(_mapCenter, 13.0);
          }
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          if (_selectedLocation == null && widget.initialLocation == null) {
            _selectedLocation = _mapCenter;
          }
        });
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Select Ad Location'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          onPressed: _selectedLocation != null
              ? () => Navigator.pop(context, _selectedLocation)
              : null,
        ),
      ),
      child: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 13.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.roadmobile.app',
              ),
              // Selected location marker
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: CupertinoColors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.location_fill,
                              color: CupertinoColors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Loading indicator
          if (_isLoadingLocation)
            Container(
              color: CupertinoColors.black.withOpacity(0.3),
              child: const Center(
                child: CupertinoActivityIndicator(radius: 20),
              ),
            ),
          
          // Instructions card
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          CupertinoIcons.hand_point_left_fill,
                          color: Color(0xFF007AFF),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tap anywhere on the map',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select where you want your ad to appear. Users within the radius will see it.',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Location info card
          if (_selectedLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            color: CupertinoColors.systemGreen,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Location Selected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${_selectedLocation?.latitude.toStringAsFixed(6) ?? '0.0'}\n'
                        'Lng: ${_selectedLocation?.longitude.toStringAsFixed(6) ?? '0.0'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          fontFamily: 'Courier',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // My Location button
          Positioned(
            right: 16,
            bottom: _selectedLocation != null ? 120 : 16,
            child: SafeArea(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  try {
                    final position = await _locationService.getCurrentPosition();
                    if (position != null) {
                      final location = LatLng(position.latitude, position.longitude);
                      setState(() {
                        _selectedLocation = location;
                      });
                      _mapController.move(location, 15.0);
                    } else {
                      throw Exception('Unable to get location');
                    }
                  } catch (e) {
                    if (mounted) {
                      showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Location Error'),
                          content: const Text(
                            'Unable to get your current location. Please check permissions.',
                          ),
                          actions: [
                            CupertinoDialogAction(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.location_fill,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

