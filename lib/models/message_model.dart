import 'package:hive/hive.dart';

part 'message_model.g.dart';

@HiveType(typeId: 0)
class Message {
  @HiveField(0)
  final String messageId;
  
  @HiveField(1)
  final String chatId;
  
  @HiveField(2)
  final String senderId;
  
  @HiveField(3)
  final String messageType; // text, image, video, audio, document
  
  @HiveField(4)
  final String? content;
  
  @HiveField(5)
  final String? mediaUrl;
  
  @HiveField(6)
  final String? replyToMessageId;
  
  @HiveField(7)
  final bool isForwarded;
  
  @HiveField(8)
  final String? forwardedFromUserId;
  
  @HiveField(9)
  final bool isEdited;
  
  @HiveField(10)
  final DateTime? editedAt;
  
  @HiveField(11)
  final bool isDeleted;
  
  @HiveField(12)
  final DateTime? deletedAt;
  
  @HiveField(13)
  final DateTime createdAt;
  
  @HiveField(14)
  final bool isDisappearing;
  
  @HiveField(15)
  final int? disappearAfterSeconds;
  
  @HiveField(16)
  final bool isDelivered;
  
  @HiveField(17)
  final bool isReadByAll;
  
  @HiveField(18)
  final DateTime? expiresAt;
  
  @HiveField(19)
  final bool isDeletedForMe;
  
  @HiveField(20)
  final List<String>? reactions;
  
  @HiveField(21)
  final bool isPinned;
  
  @HiveField(22)
  final DateTime? scheduledFor;

  Message({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.messageType,
    this.content,
    this.mediaUrl,
    this.replyToMessageId,
    this.isForwarded = false,
    this.forwardedFromUserId,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    this.isDisappearing = false,
    this.disappearAfterSeconds,
    this.isDelivered = false,
    this.isReadByAll = false,
    this.expiresAt,
    this.isDeletedForMe = false,
    this.reactions,
    this.isPinned = false,
    this.scheduledFor,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: json['message_id'],
      chatId: json['chat_id'],
      senderId: json['sender_id'],
      messageType: json['message_type'],
      content: json['content'],
      mediaUrl: json['media_url'],
      replyToMessageId: json['reply_to_message_id'],
      isForwarded: json['is_forwarded'] ?? false,
      forwardedFromUserId: json['forwarded_from_user_id'],
      isEdited: json['is_edited'] ?? false,
      editedAt: json['edited_at'] != null ? DateTime.parse(json['edited_at']) : null,
      isDeleted: json['is_deleted'] ?? false,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      isDisappearing: json['is_disappearing'] ?? false,
      disappearAfterSeconds: json['disappear_after_seconds'],
      isDelivered: json['is_delivered'] ?? false,
      isReadByAll: json['is_read_by_all'] ?? false,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      isPinned: json['is_pinned'] ?? false,
      scheduledFor: json['scheduled_for'] != null ? DateTime.parse(json['scheduled_for']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'chat_id': chatId,
      'sender_id': senderId,
      'message_type': messageType,
      'content': content,
      'media_url': mediaUrl,
      'reply_to_message_id': replyToMessageId,
      'is_forwarded': isForwarded,
      'forwarded_from_user_id': forwardedFromUserId,
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_disappearing': isDisappearing,
      'disappear_after_seconds': disappearAfterSeconds,
      'is_delivered': isDelivered,
      'is_read_by_all': isReadByAll,
      'expires_at': expiresAt?.toIso8601String(),
      'scheduled_for': scheduledFor?.toIso8601String(),
    };
  }

  Message copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? messageType,
    String? content,
    String? mediaUrl,
    String? replyToMessageId,
    bool? isForwarded,
    String? forwardedFromUserId,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    bool? isDisappearing,
    int? disappearAfterSeconds,
    bool? isDelivered,
    bool? isReadByAll,
    DateTime? expiresAt,
    bool? isDeletedForMe,
    List<String>? reactions,
    bool? isPinned,
    DateTime? scheduledFor,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedFromUserId: forwardedFromUserId ?? this.forwardedFromUserId,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      isDisappearing: isDisappearing ?? this.isDisappearing,
      disappearAfterSeconds: disappearAfterSeconds ?? this.disappearAfterSeconds,
      isDelivered: isDelivered ?? this.isDelivered,
      isReadByAll: isReadByAll ?? this.isReadByAll,
      expiresAt: expiresAt ?? this.expiresAt,
      isDeletedForMe: isDeletedForMe ?? this.isDeletedForMe,
      reactions: reactions ?? this.reactions,
      isPinned: isPinned ?? this.isPinned,
      scheduledFor: scheduledFor ?? this.scheduledFor,
    );
  }
}