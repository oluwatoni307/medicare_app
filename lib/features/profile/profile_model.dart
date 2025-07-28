/// === PROFILE MODELS ===
/// Purpose: Data models for profile page user data and statistics

/// User profile data model
class ProfileUserModel {
  final String id;
  final String name;
  final String? email;
  final DateTime? createdAt;

  const ProfileUserModel({
    required this.id,
    required this.name,
    this.email,
    this.createdAt,
  });

  factory ProfileUserModel.fromJson(Map<String, dynamic> json) {
    return ProfileUserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Get formatted member since date
  String get memberSinceFormatted {
    if (createdAt == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(createdAt!);
    
    if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    }
  }

  ProfileUserModel copyWith({
    String? id,
    String? name,
    String? email,
    DateTime? createdAt,
  }) {
    return ProfileUserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Minimal statistics for profile page
class ProfileStatsModel {
  final int totalMedicines;
  final DateTime? lastActivity;

  const ProfileStatsModel({
    required this.totalMedicines,
    this.lastActivity,
  });

  factory ProfileStatsModel.fromJson(Map<String, dynamic> json) {
    return ProfileStatsModel(
      totalMedicines: json['total_medicines'] as int? ?? 0,
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'] as String)
          : null,
    );
  }

  /// Get formatted last activity
  String get lastActivityFormatted {
    if (lastActivity == null) return 'No recent activity';
    
    final now = DateTime.now();
    final difference = now.difference(lastActivity!);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return 'Over a week ago';
    }
  }

  ProfileStatsModel copyWith({
    int? totalMedicines,
    DateTime? lastActivity,
  }) {
    return ProfileStatsModel(
      totalMedicines: totalMedicines ?? this.totalMedicines,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}

/// Combined profile data
class ProfileModel {
  final ProfileUserModel user;
  final ProfileStatsModel stats;

  const ProfileModel({
    required this.user,
    required this.stats,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      user: ProfileUserModel.fromJson(json['user'] as Map<String, dynamic>),
      stats: ProfileStatsModel.fromJson(json['stats'] as Map<String, dynamic>),
    );
  }

  ProfileModel copyWith({
    ProfileUserModel? user,
    ProfileStatsModel? stats,
  }) {
    return ProfileModel(
      user: user ?? this.user,
      stats: stats ?? this.stats,
    );
  }
}