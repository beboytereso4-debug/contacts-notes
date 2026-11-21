class Contact {
  final int? id;
  final String name;
  final String phone;
  final String email;
  final bool isFavorite;
  final int? createdAt;
  final String? photoPath;

  const Contact({
    this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.isFavorite = false,
    this.createdAt,
    this.photoPath,
  });

  Contact copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    bool? isFavorite,
    int? createdAt,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'is_favorite': isFavorite ? 1 : 0,
        'created_at': createdAt,
        'photo_path': photoPath,
      };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String,
        email: (map['email'] as String?) ?? '',
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
        createdAt: map['created_at'] as int?,
        photoPath: map['photo_path'] as String?,
      );
}
