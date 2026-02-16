import 'package:hive/hive.dart';

part 'chat_model.g.dart';

@HiveType(typeId: 2)
class ChatModel {
  @HiveField(0)
  final String chatId;
  
  @HiveField(1)
  final String chatType; // private, group, channel
  
  @HiveField(2)
  final String? user1Id;
  
  @HiveField(3)
  final String? user2Id;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final DateTime updatedAt;
  
  @HiveField(6)
  final DateTime? lastMessageAt;
  
  @HiveField(7)
  final int? autoDeleteDays;
  
  @HiveField(8)
  final String? lastMessageBy;
  
  @HiveField(9)
  final int unreadCount;
  
  @HiveField(10)
  final bool isMuted;
  
  @HiveField(11)
  final bool isArchived;
  
  @HiveField(12)
  final bool isPinned;

  ChatModel({
    required this.chatId,
    required this.chatType,
    this.user1Id,
    this.user2Id,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.autoDeleteDays,
    this.lastMessageBy,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isArchived = false,
    this.isPinned = false,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      chatId: json['chat_id'],
      chatType: json['chat_type'],
      user1Id: json['user1_id'],
      user2Id: json['user2_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastMessageAt: json['last_message_at'] != null 
          ? DateTime.parse(json['last_message_at']) 
          : null,
      autoDeleteDays: json['auto_delete_days'],
      lastMessageBy: json['last_message_by'],
      unreadCount: json['unread_count'] ?? 0,
      isMuted: json['is_muted'] ?? false,
      isArchived: json['is_archived'] ?? false,
      isPinned: json['is_pinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'chat_type': chatType,
      'user1_id': user1Id,
      'user2_id': user2Id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'auto_delete_days': autoDeleteDays,
      'last_message_by': lastMessageBy,
      'unread_count': unreadCount,
      'is_muted': isMuted,
      'is_archived': isArchived,
      'is_pinned': isPinned,
    };
  }

  ChatModel copyWith({
    String? chatId,
    String? chatType,
    String? user1Id,
    String? user2Id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    int? autoDeleteDays,
    String? lastMessageBy,
    int? unreadCount,
    bool? isMuted,
    bool? isArchived,
    bool? isPinned,
  }) {
    return ChatModel(
      chatId: chatId ?? this.chatId,
      chatType: chatType ?? this.chatType,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      autoDeleteDays: autoDeleteDays ?? this.autoDeleteDays,
      lastMessageBy: lastMessageBy ?? this.lastMessageBy,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}