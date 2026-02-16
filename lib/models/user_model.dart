import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 1)
class UserModel {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final String? fullName;

  @HiveField(2)
  final String? username;

  @HiveField(3)
  final String? mobile;

  @HiveField(4)
  final String? email;

  @HiveField(5)
  final String? bio;

  @HiveField(6)
  final String? profilePictureUrl;

  @HiveField(7)
  final bool isOnline;

  @HiveField(8)
  final DateTime? lastSeen;

  @HiveField(9)
  final bool isVerified;

  @HiveField(10)
  final DateTime? accountCreatedAt;

  UserModel({
    required this.userId,
    this.fullName,
    this.username,
    this.mobile,
    this.email,
    this.bio,
    this.profilePictureUrl,
    this.isOnline = false,
    this.lastSeen,
    this.isVerified = false,
    this.accountCreatedAt,
  });

  // ✅ Display name with priority: fullName > username > mobile
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }
    if (username != null && username!.isNotEmpty) {
      return username!;
    }
    if (mobile != null && mobile!.isNotEmpty) {
      return mobile!;
    }
    return 'Unknown User';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String?,
      username: json['username'] as String?,
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      isVerified: json['is_verified'] as bool? ?? false,
      accountCreatedAt: json['account_created_at'] != null
          ? DateTime.parse(json['account_created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'full_name': fullName,
      'username': username,
      'mobile': mobile,
      'email': email,
      'bio': bio,
      'profile_picture_url': profilePictureUrl,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'is_verified': isVerified,
      'account_created_at': accountCreatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? userId,
    String? fullName,
    String? username,
    String? mobile,
    String? email,
    String? bio,
    String? profilePictureUrl,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isVerified,
    DateTime? accountCreatedAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isVerified: isVerified ?? this.isVerified,
      accountCreatedAt: accountCreatedAt ?? this.accountCreatedAt,
    );
  }
}