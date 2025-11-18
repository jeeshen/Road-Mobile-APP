import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/district.dart';
import 'navigation_screen.dart';
import '../models/post.dart';

class DestinationSearchScreen extends StatefulWidget {
  final Position currentPosition;
  final List<District> districts;
  final List<Post> allPosts;

  const DestinationSearchScreen({
    super.key,
    required this.currentPosition,
    required this.districts,
    required this.allPosts,
  });

  @override
  State<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  static const String _photonBaseUrl = 'https://photon.komoot.io/api/';
  static const String _malaysiaBbox = '94.0,-1.0,120.0,8.0';

  Timer? _searchDebounce;
  int _searchRequestId = 0;
  List<District> _filteredDistricts = [];
  List<_RecentDestination> _recentDestinations = [];
  List<_AddressResult> _addressResults = [];
  LatLng? _selectedLocation;
  String? _selectedLocationName;
  bool _isMapMode = false;
  bool _isSearchingAddress = false;
  String? _addressError;

  @override
  void initState() {
    super.initState();
    _filteredDistricts = widget.districts;
    _loadRecentDestinations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _loadRecentDestinations() {
    // In production, load from SharedPreferences
    // For now, show popular districts
    _recentDestinations = [
      _RecentDestination(
        name: 'Kuala Lumpur City Centre',
        location: const LatLng(3.1570, 101.7116),
      ),
      _RecentDestination(
        name: 'Petaling Jaya',
        location: const LatLng(3.1073, 101.6067),
      ),
      _RecentDestination(
        name: 'Shah Alam',
        location: const LatLng(3.0738, 101.5183),
      ),
    ];
  }

  void _onSearchChanged(String query) {
    _filterDistricts(query);
    _debounceAddressLookup(query);
  }

  void _filterDistricts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDistricts = widget.districts;
      } else {
        _filteredDistricts = widget.districts.where((district) {
          return district.name.toLowerCase().contains(query.toLowerCase()) ||
              district.state.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _debounceAddressLookup(String query) {
    _searchDebounce?.cancel();

    if (query.trim().length < 3) {
      setState(() {
        _addressResults = [];
        _addressError = null;
        _isSearchingAddress = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _searchAddress(query.trim());
    });
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    final currentRequestId = ++_searchRequestId;
    setState(() {
      _isSearchingAddress = true;
      _addressError = null;
    });

    try {
      final uri = Uri.parse(
        '$_photonBaseUrl'
        '?q=${Uri.encodeComponent(query)}'
        '&limit=8&lang=en&bbox=$_malaysiaBbox',
      );
      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent': 'roadmobile-app/1.0 (+https://roadmobile.app)',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (currentRequestId != _searchRequestId) {
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Photon failed (${response.statusCode})');
      }

      final data = json.decode(response.body);
      if (data is! Map || data['features'] is! List) {
        throw Exception('Unexpected response');
      }

      final features = (data['features'] as List)
          .whereType<Map>()
          .map((feature) => Map<String, dynamic>.from(feature))
          .toList();

      final results = features
          .map<_AddressResult?>((feature) {
            final geometry = feature['geometry'] is Map
                ? Map<String, dynamic>.from(feature['geometry'] as Map)
                : null;
            final properties = feature['properties'] is Map
                ? Map<String, dynamic>.from(feature['properties'] as Map)
                : null;
            if (geometry == null || properties == null) return null;

            final coords = geometry['coordinates'];
            if (coords is! List || coords.length < 2) return null;

            final lon = (coords[0] as num?)?.toDouble();
            final lat = (coords[1] as num?)?.toDouble();
            if (lat == null || lon == null) return null;

            final country = (properties['country'] as String?)?.toLowerCase();
            if (country != null && !country.contains('malaysia')) {
              return null;
            }

            final addressMap = _buildPhotonAddressMap(properties);
            final rawName =
                properties['name'] as String? ??
                properties['street'] as String? ??
                query;

            final fallbackTitle = rawName
                .split(',')
                .first
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ');

            return _AddressResult(
              title: _formatAddressTitle(addressMap, fallbackTitle),
              subtitle: _formatAddressSubtitle(
                addressMap,
                _composePhotonDisplayName(properties),
              ),
              location: LatLng(lat, lon),
            );
          })
          .whereType<_AddressResult>()
          .toList();

      setState(() {
        _addressResults = results;
      });
    } catch (e) {
      if (currentRequestId == _searchRequestId) {
        setState(() {
          _addressError = 'Unable to find that address. Try another search.';
          _addressResults = [];
        });
      }
    } finally {
      if (currentRequestId == _searchRequestId) {
        setState(() {
          _isSearchingAddress = false;
        });
      }
    }
  }

  String _formatAddressTitle(Map<String, dynamic>? address, String fallback) {
    if (address == null) {
      return fallback;
    }

    final components = <String>[];

    void addComponent(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          components.add(trimmed);
        }
      }
    }

    addComponent(address['road'] ?? address['street']);
    addComponent(
      address['neighbourhood'] ??
          address['suburb'] ??
          address['residential'] ??
          address['hamlet'],
    );
    addComponent(
      address['city'] ??
          address['town'] ??
          address['village'] ??
          address['municipality'] ??
          address['county'],
    );

    final cleaned = _cleanComponents(components);
    if (cleaned.isEmpty) {
      final fallbackParts = fallback
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      return fallbackParts.take(2).join(', ');
    }

    return cleaned.take(2).join(', ');
  }

  String _formatAddressSubtitle(
    Map<String, dynamic>? address,
    String displayName,
  ) {
    if (address == null) {
      return displayName;
    }

    final components = <String>[];

    void addComponent(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        components.add(value.trim());
      }
    }

    addComponent(
      address['state'] ??
          address['state_district'] ??
          address['region'] ??
          address['county'],
    );
    addComponent(address['postcode']);
    addComponent('Malaysia');

    final cleaned = _cleanComponents(components);
    return cleaned.isEmpty ? displayName : cleaned.join(', ');
  }

  List<String> _cleanComponents(List<String> components) {
    final seen = <String>{};
    final cleaned = <String>[];

    for (final component in components) {
      if (!seen.contains(component)) {
        seen.add(component);
        cleaned.add(component);
      }
    }
    return cleaned;
  }

  Map<String, dynamic> _buildPhotonAddressMap(Map<String, dynamic> properties) {
    return {
      'road': properties['street'] ?? properties['name'],
      'neighbourhood':
          properties['neighbourhood'] ??
          properties['district'] ??
          properties['suburb'],
      'suburb': properties['suburb'],
      'city':
          properties['city'] ??
          properties['town'] ??
          properties['state_district'] ??
          properties['county'],
      'municipality': properties['state_district'],
      'county': properties['county'],
      'state': properties['state'],
      'postcode': properties['postcode'],
      'country': properties['country'],
    };
  }

  String _composePhotonDisplayName(Map<String, dynamic> properties) {
    final parts = <String>[];
    final keys = [
      'name',
      'street',
      'district',
      'city',
      'state',
      'postcode',
      'country',
    ];

    for (final key in keys) {
      final value = properties[key];
      if (value is String && value.trim().isNotEmpty) {
        parts.add(value.trim());
      }
    }

    if (!parts.contains('Malaysia')) {
      parts.add('Malaysia');
    }
    return parts.join(', ');
  }

  void _selectDestination(LatLng location, String name) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => NavigationScreen(
          destination: location,
          destinationName: name,
          currentPosition: widget.currentPosition,
          allPosts: widget.allPosts,
          districts: widget.districts,
        ),
      ),
    );
  }

  void _enterMapMode() {
    setState(() {
      _isMapMode = true;
    });
  }

  void _exitMapMode() {
    setState(() {
      _isMapMode = false;
      _selectedLocation = null;
      _selectedLocationName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Choose Destination'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: _isMapMode
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('Cancel'),
                onPressed: _exitMapMode,
              )
            : CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.map),
                onPressed: _enterMapMode,
              ),
      ),
      child: _isMapMode ? _buildMapView() : _buildSearchView(),
    );
  }

  Widget _buildSearchView() {
    final isSearchActive = _searchController.text.trim().isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Search district or enter address',
                  onChanged: _onSearchChanged,
                  prefixIcon: const Icon(CupertinoIcons.search),
                  style: const TextStyle(fontSize: 17),
                  onSubmitted: (value) => _searchAddress(value.trim()),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: CupertinoColors.systemBlue,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: _enterMapMode,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.map,
                        size: 20,
                        color: CupertinoColors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Select Anywhere on Map',
                        style: TextStyle(color: CupertinoColors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (!isSearchActive) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final destination = _recentDestinations[index];
                      return _buildDestinationTile(
                        name: destination.name,
                        subtitle: 'Recent destination',
                        icon: CupertinoIcons.clock,
                        iconColor: CupertinoColors.systemGrey,
                        onTap: () => _selectDestination(
                          destination.location,
                          destination.name,
                        ),
                      );
                    }, childCount: _recentDestinations.length),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text(
                        'All Districts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final district = _filteredDistricts[index];
                      return _buildDestinationTile(
                        name: district.name,
                        subtitle: district.state,
                        icon: CupertinoIcons.location_fill,
                        iconColor: CupertinoColors.systemRed,
                        onTap: () => _selectDestination(
                          LatLng(district.latitude, district.longitude),
                          district.name,
                        ),
                      );
                    }, childCount: _filteredDistricts.length),
                  ),
                ] else ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        'Addresses in Malaysia',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (_isSearchingAddress)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CupertinoActivityIndicator(radius: 12),
                        ),
                      ),
                    )
                  else if (_addressError != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Text(
                          _addressError!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: CupertinoColors.systemRed,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else if (_addressResults.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final result = _addressResults[index];
                        return _buildDestinationTile(
                          name: result.title,
                          subtitle: result.subtitle,
                          icon: CupertinoIcons.house_fill,
                          iconColor: CupertinoColors.systemBlue,
                          onTap: () =>
                              _selectDestination(result.location, result.title),
                        );
                      }, childCount: _addressResults.length),
                    ),
                  if (!_isSearchingAddress &&
                      _addressError == null &&
                      _addressResults.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.search,
                              size: 64,
                              color: CupertinoColors.systemGrey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No Malaysian addresses found',
                              style: TextStyle(
                                fontSize: 17,
                                color: CupertinoColors.secondaryLabel,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(
              widget.currentPosition.latitude,
              widget.currentPosition.longitude,
            ),
            initialZoom: 13.0,
            minZoom: 6.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              enableMultiFingerGestureRace: true,
            ),
            onTap: (tapPosition, point) {
              setState(() {
                _selectedLocation = point;
                _selectedLocationName =
                    'Custom Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.roadmobile.app',
              retinaMode: RetinaMode.isHighDensity(context),
            ),
            // Current position marker
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(
                    widget.currentPosition.latitude,
                    widget.currentPosition.longitude,
                  ),
                  width: 50,
                  height: 50,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CupertinoColors.white,
                        width: 3,
                      ),
                    ),
                  ),
                ),
                // Selected location marker
                if (_selectedLocation != null)
                  Marker(
                    point: _selectedLocation!,
                    width: 40,
                    height: 50,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CupertinoColors.white,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.placemark_fill,
                            color: CupertinoColors.white,
                            size: 18,
                          ),
                        ),
                        Container(
                          width: 3,
                          height: 12,
                          color: CupertinoColors.systemRed,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        // Instructions overlay
        if (_selectedLocation == null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    CupertinoIcons.hand_point_left,
                    color: CupertinoColors.systemBlue,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap anywhere on the map to set destination',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Confirm button
        if (_selectedLocation != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedLocationName ?? 'Selected Location',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: CupertinoColors.systemBlue,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () {
                        if (_selectedLocation != null) {
                          _selectDestination(
                            _selectedLocation!,
                            _selectedLocationName ?? 'Custom Location',
                          );
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.location_fill,
                            color: CupertinoColors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Navigate to This Location',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
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

  Widget _buildDestinationTile({
    required String name,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          size: 20,
          color: CupertinoColors.tertiaryLabel,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _RecentDestination {
  final String name;
  final LatLng location;

  _RecentDestination({required this.name, required this.location});
}

class _AddressResult {
  final String title;
  final String subtitle;
  final LatLng location;

  _AddressResult({
    required this.title,
    required this.subtitle,
    required this.location,
  });
}
