class UserProfile {
  final String id;
  final String fullName;
  final String avatarUrl;
  final int currentHskLevel;
  final int streak;
  final DateTime lastActiveDate;
  final int totalXp;
  final int coins;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.avatarUrl,
    required this.currentHskLevel,
    required this.streak,
    required this.lastActiveDate,
    required this.totalXp,
    required this.coins,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'Pelajar Mandarin').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      currentHskLevel: (json['current_hsk_level'] as num?)?.toInt() ?? 1,
      streak: (json['streak'] as num?)?.toInt() ?? 1,
      lastActiveDate: json['last_active_date'] != null
          ? DateTime.tryParse(json['last_active_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'current_hsk_level': currentHskLevel,
    'streak': streak,
    'last_active_date': lastActiveDate.toIso8601String().split('T').first,
    'total_xp': totalXp,
    'coins': coins,
  };

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    int? currentHskLevel,
    int? streak,
    DateTime? lastActiveDate,
    int? totalXp,
    int? coins,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currentHskLevel: currentHskLevel ?? this.currentHskLevel,
      streak: streak ?? this.streak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      totalXp: totalXp ?? this.totalXp,
      coins: coins ?? this.coins,
    );
  }
}
