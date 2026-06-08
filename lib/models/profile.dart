class Profile {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final int streak;
  final int totalXp;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.streak = 0,
    this.totalXp = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Profile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    int? streak,
    int? totalXp,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      streak: streak ?? this.streak,
      totalXp: totalXp ?? this.totalXp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Usuario',
      avatarUrl: json['avatar_url'] as String?,
      streak: json['streak'] as int? ?? 0,
      totalXp: json['total_xp'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'streak': streak,
      'total_xp': totalXp,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
