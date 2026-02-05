enum ChatType { personal, group, channel }

class ChatItem {
  final String chatId;
  final String name;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final ChatType chatType;

  ChatItem({
    required this.chatId,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.chatType = ChatType.personal,
  });
}
