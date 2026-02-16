import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../utils/emoji_util.dart';
import '../utils/date_util.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final UserModel? sender;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onSaveMedia;
  final Message? replyToMessage;

  const MessageBubble({
    Key? key,
    required this.message,
    this.sender,
    required this.isMe,
    this.showAvatar = false,
    this.onLongPress,
    this.onReply,
    this.onForward,
    this.onCopy,
    this.onDelete,
    this.onEdit,
    this.onSaveMedia,
    this.replyToMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted && !message.isDeletedForMe) {
      return _buildDeletedMessage(context);
    }

    final isOnlyEmojis = message.content != null && 
        EmojiUtil.shouldShowWithoutBubble(message.content!);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && showAvatar) _buildAvatar(),
            if (!isMe && !showAvatar) const SizedBox(width: 40),
            
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.isPinned) _buildPinnedIndicator(context),
                  
                  if (isOnlyEmojis)
                    _buildEmojiOnlyMessage(context)
                  else
                    _buildStandardMessage(context),
                ],
              ),
            ),
            
            if (isMe && showAvatar) _buildAvatar(),
            if (isMe && !showAvatar) const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: sender?.profilePictureUrl != null
            ? CachedNetworkImageProvider(sender!.profilePictureUrl!)
            : null,
        child: sender?.profilePictureUrl == null
            ? Text(
                sender?.displayName.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(fontSize: 14),
              )
            : null,
      ),
    );
  }

  Widget _buildPinnedIndicator(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.push_pin,
            size: 14,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            'Pinned',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiOnlyMessage(BuildContext context) {
    final fontSize = EmojiUtil.getEmojiFontSize(message.content!);
    
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          message.content!,
          style: TextStyle(fontSize: fontSize),
        ),
        const SizedBox(height: 2),
        _buildMessageFooter(context, showInline: false),
      ],
    );
  }

  Widget _buildStandardMessage(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyToMessageId != null && replyToMessage != null)
            _buildReplyPreview(context),
          
          if (message.isForwarded) _buildForwardedLabel(context),
          
          if (message.mediaUrl != null) _buildMediaContent(context),
          
          if (message.content != null && message.content!.isNotEmpty)
            _buildTextContent(context),
          
          _buildMessageFooter(context),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyToMessage?.senderId == sender?.userId
                ? 'You'
                : sender?.displayName ?? 'Unknown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyToMessage?.content ?? 'Media',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForwardedLabel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forward,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'Forwarded',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _getMediaWidget(context),
      ),
    );
  }

  Widget _getMediaWidget(BuildContext context) {
    if (message.messageType == 'image') {
      return CachedNetworkImage(
        imageUrl: message.mediaUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 200,
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 200,
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        ),
      );
    } else if (message.messageType == 'video') {
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 200,
            color: Colors.black,
          ),
          const Icon(Icons.play_circle_outline, size: 64, color: Colors.white),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTextContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        message.content!,
        style: TextStyle(
          fontSize: 16,
          color: isMe
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMessageFooter(BuildContext context, {bool showInline = true}) {
    return Padding(
      padding: showInline 
          ? const EdgeInsets.fromLTRB(12, 0, 12, 8)
          : EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isEdited)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'edited',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          
          Text(
            DateUtil.formatMessageTime(message.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: showInline
                  ? (isMe
                      ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7))
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          
          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(
              message.isReadByAll
                  ? Icons.done_all
                  : message.isDelivered
                      ? Icons.done_all
                      : Icons.done,
              size: 14,
              color: message.isReadByAll
                  ? Colors.blue
                  : (showInline
                      ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeletedMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'This message was deleted',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}