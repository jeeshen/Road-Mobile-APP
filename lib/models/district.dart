class District {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String state;

  District({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.state,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'state': state,
    };
  }

  factory District.fromMap(Map<String, dynamic> map) {
    return District(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      state: map['state'] ?? '',
    );
  }
}



