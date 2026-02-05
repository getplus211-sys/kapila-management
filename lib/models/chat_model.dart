// Chat Types Enum
enum ChatType {
  private,
  group,
  channel,
}

// Chat Item Model - For chat list
class ChatItem {
  final String chatId;
  final ChatType chatType;
  final String name;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool? isOnline;
  final DateTime? lastSeen;

  ChatItem({
    required this.chatId,
    required this.chatType,
    required this.name,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isOnline,
    this.lastSeen,
  });
}

// Message Model - For individual messages
class Message {
  final String messageId;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String messageType;
  final String? content;
  final String? mediaUrl;
  final String? replyToMessageId;
  final bool isForwarded;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDelivered;
  final bool isRead;

  Message({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.messageType,
    this.content,
    this.mediaUrl,
    this.replyToMessageId,
    this.isForwarded = false,
    this.isEdited = false,
    this.isDeleted = false,
    required this.createdAt,
    this.editedAt,
    this.isDelivered = false,
    this.isRead = false,
  });

  Message copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? messageType,
    String? content,
    String? mediaUrl,
    String? replyToMessageId,
    bool? isForwarded,
    bool? isEdited,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? editedAt,
    bool? isDelivered,
    bool? isRead,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isForwarded: isForwarded ?? this.isForwarded,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
    );
  }
}

// Contact Model - For contacts list
class Contact {
  final String userId;
  final String name;
  final String? username;
  final String? profilePictureUrl;
  final bool isOnline;
  final String? phoneNumber;

  Contact({
    required this.userId,
    required this.name,
    this.username,
    this.profilePictureUrl,
    this.isOnline = false,
    this.phoneNumber,
  });
}