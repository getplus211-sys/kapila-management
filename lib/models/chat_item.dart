enum ChatType {
  private,
  group,
  channel,
}

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
    required this.unreadCount,
    required this.isPinned,
    required this.isMuted,
    this.isOnline,
    this.lastSeen,
  });

  // ✅ CRITICAL: copyWith method
  ChatItem copyWith({
    String? chatId,
    ChatType? chatType,
    String? name,
    String? avatarUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return ChatItem(
      chatId: chatId ?? this.chatId,
      chatType: chatType ?? this.chatType,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  factory ChatItem.fromJson(Map<String, dynamic> json) {
    return ChatItem(
      chatId: json['chatId'],
      chatType: ChatType.values.firstWhere(
        (e) => e.toString() == json['chatType'],
        orElse: () => ChatType.private,
      ),
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      lastMessage: json['lastMessage'],
      lastMessageTime: DateTime.parse(json['lastMessageTime']),
      unreadCount: json['unreadCount'] ?? 0,
      isPinned: json['isPinned'] ?? false,
      isMuted: json['isMuted'] ?? false,
      isOnline: json['isOnline'],
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'chatType': chatType.toString(),
      'name': name,
      'avatarUrl': avatarUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isPinned': isPinned,
      'isMuted': isMuted,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }
}