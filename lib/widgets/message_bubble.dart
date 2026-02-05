import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onForward;
  final Function(String emoji) onReact;
  final Function(String replyId) onJumpToReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showAvatar,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onLongPress,
    this.onTap,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onForward,
    required this.onReact,
    required this.onJumpToReply,
  });

  bool _isEmojiOnly(String text) {
    // Remove all whitespace
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Check if it's 1-3 emojis only
    final emojiRegex = RegExp(
      r'^(?:[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F900}-\u{1F9FF}]|[\u{1F018}-\u{1F270}]|[\u{238C}-\u{2454}]|[\u{20D0}-\u{20FF}]|[\u{FE0F}]|\u{200D})+$',
      unicode: true,
    );

    if (!emojiRegex.hasMatch(trimmed)) return false;

    // Count number of emojis (simplified - count by regex matches)
    final emojiCount = RegExp(
      r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F900}-\u{1F9FF}]',
      unicode: true,
    ).allMatches(trimmed).length;

    return emojiCount <= 3;
  }

  @override
  Widget build(BuildContext context) {
    final isEmojiOnlyMessage = message.content != null && _isEmojiOnly(message.content!);

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap ?? () {
        if (!isSelectionMode) {
          _showMessageOptions(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundImage: message.senderAvatar != null
                    ? NetworkImage(message.senderAvatar!)
                    : null,
                child: message.senderAvatar == null
                    ? Text(
                        (message.senderName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              )
            else if (!isMe)
              const SizedBox(width: 32),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 8),
                      child: Text(
                        message.senderName ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6F00),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF6F00).withOpacity(0.3)
                          : isEmojiOnlyMessage
                              ? Colors.transparent
                              : isMe
                                  ? const Color(0xFFDCF8C6)
                                  : Colors.white,
                      borderRadius: BorderRadius.circular(isEmojiOnlyMessage ? 0 : 12),
                      boxShadow: isEmojiOnlyMessage
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    padding: isEmojiOnlyMessage
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.isForwarded)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.forward, size: 14, color: Colors.grey),
                                SizedBox(width: 4),
                                Text(
                                  'Forwarded',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (message.replyToMessageId != null) _buildReplyPreview(context),
                        if (message.content != null)
                          Text(
                            message.content!,
                            style: TextStyle(
                              fontSize: isEmojiOnlyMessage ? 48 : 15,
                              color: isEmojiOnlyMessage ? null : Colors.black87,
                            ),
                          ),
                        if (message.mediaUrl != null) _buildMediaContent(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.isEdited)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Text(
                                  'edited',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            Text(
                              DateFormat('HH:mm').format(message.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: isEmojiOnlyMessage ? Colors.grey[600] : Colors.grey,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.isRead
                                    ? Icons.done_all
                                    : message.isDelivered
                                        ? Icons.done_all
                                        : Icons.done,
                                size: 14,
                                color: message.isRead ? Colors.blue : Colors.grey,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return GestureDetector(
      onTap: () => onJumpToReply(message.replyToMessageId!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.green : const Color(0xFFFF6F00),
              width: 3,
            ),
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replied message',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF6F00),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Tap to view',
              style: TextStyle(fontSize: 12, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (message.messageType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          message.mediaUrl!,
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 50),
            );
          },
        ),
      );
    } else if (message.messageType == 'video') {
      return Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_outline, size: 50, color: Colors.white),
        ),
      );
    } else if (message.messageType == 'document') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: Color(0xFFFF6F00)),
            SizedBox(width: 8),
            Text('Document', style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reactions row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildReactionButton(context, '❤️'),
                  _buildReactionButton(context, '👍'),
                  _buildReactionButton(context, '😂'),
                  _buildReactionButton(context, '😮'),
                  _buildReactionButton(context, '😢'),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply();
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                onForward();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                // Implement copy functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(BuildContext context, String emoji) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onReact(emoji);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}