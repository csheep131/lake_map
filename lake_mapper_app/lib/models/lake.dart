class Lake {
  final int? id;
  final String name;
  final DateTime createdAt;

  Lake({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Lake.fromMap(Map<String, dynamic> map) {
    return Lake(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Lake copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Lake(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}