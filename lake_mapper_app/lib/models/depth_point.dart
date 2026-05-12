class DepthPoint {
  final int? id;
  final int lakeId;
  final double latitude;
  final double longitude;
  final double depthM;
  final double? accuracyM;
  final String? note;
  final DateTime createdAt;
  final int? pointNumber;

  DepthPoint({
    this.id,
    required this.lakeId,
    required this.latitude,
    required this.longitude,
    required this.depthM,
    this.accuracyM,
    this.note,
    required this.createdAt,
    this.pointNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lake_id': lakeId,
      'latitude': latitude,
      'longitude': longitude,
      'depth_m': depthM,
      'accuracy_m': accuracyM,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'point_number': pointNumber,
    };
  }

  factory DepthPoint.fromMap(Map<String, dynamic> map) {
    return DepthPoint(
      id: map['id'] as int?,
      lakeId: (map['lake_id'] as num?)?.toInt() ?? 1,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      depthM: (map['depth_m'] as num?)?.toDouble() ?? 0.0,
      accuracyM: (map['accuracy_m'] as num?)?.toDouble(),
      note: map['note'] as String?,
      createdAt: DateTime.tryParse(map['measured_at'] as String? ?? map['created_at'] as String? ?? '') ?? DateTime.now(),
      pointNumber: (map['point_number'] as num?)?.toInt(),
    );
  }

  DepthPoint copyWith({
    int? id,
    int? lakeId,
    double? latitude,
    double? longitude,
    double? depthM,
    double? accuracyM,
    String? note,
    DateTime? createdAt,
    int? pointNumber,
  }) {
    return DepthPoint(
      id: id ?? this.id,
      lakeId: lakeId ?? this.lakeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      depthM: depthM ?? this.depthM,
      accuracyM: accuracyM ?? this.accuracyM,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      pointNumber: pointNumber ?? this.pointNumber,
    );
  }
}