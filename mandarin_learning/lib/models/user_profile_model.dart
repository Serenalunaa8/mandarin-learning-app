class UserProfile {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String avatarUrl;
  final int currentHskLevel;
  final int streak;
  final DateTime lastActiveDate;
  final int coins;

  UserProfile({
    required this.id,
    this.username = '',
    this.email = '',
    required this.fullName,
    required this.avatarUrl,
    required this.currentHskLevel,
    required this.streak,
    required this.lastActiveDate,
    required this.coins,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'Pelajar Mandarin').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      currentHskLevel: (json['current_hsk_level'] as num?)?.toInt() ?? 1,
      streak: (json['streak'] as num?)?.toInt() ?? 1,
      lastActiveDate: json['last_active_date'] != null
          ? DateTime.tryParse(json['last_active_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      coins: (json['coins'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'current_hsk_level': currentHskLevel,
    'streak': streak,
    'last_active_date': lastActiveDate.toIso8601String().split('T').first,
    'coins': coins,
  };

  UserProfile copyWith({
    String? username,
    String? email,
    String? fullName,
    String? avatarUrl,
    int? currentHskLevel,
    int? streak,
    DateTime? lastActiveDate,
    int? coins,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currentHskLevel: currentHskLevel ?? this.currentHskLevel,
      streak: streak ?? this.streak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      coins: coins ?? this.coins,
    );
  }
}
