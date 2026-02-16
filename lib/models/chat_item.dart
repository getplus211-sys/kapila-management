import '../models/chat_item.dart';
enum ChatType { private, group, channel }

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

  factory ChatItem.fromJson(Map<String, dynamic> json) {
    return ChatItem(
      chatId: json['chatId'],
      chatType: ChatType.values.firstWhere(
        (e) => e.toString() == json['chatType'],
      ),
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      lastMessage: json['lastMessage'],
      lastMessageTime: DateTime.parse(json['lastMessageTime']),
      unreadCount: json['unreadCount'] ?? 0,
      isPinned: json['isPinned'] ?? false,
      isMuted: json['isMuted'] ?? false,
      isOnline: json['isOnline'],
      lastSeen: json['lastSeen'] != null 
          ? DateTime.parse(json['lastSeen']) 
          : null,
    );
  }
}