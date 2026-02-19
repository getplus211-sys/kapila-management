import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../utils/date_util.dart';

const _kBg      = Color(0xFF0B0E1A);
const _kSurface = Color(0xFF141828);
const _kSurf2   = Color(0xFF1C2035);
const _kBrand   = Color(0xFF7B4FD6);
const _kAccent  = Color(0xFF9B6FF0);
const _kText1   = Color(0xFFEEEEF5);
const _kText2   = Color(0xFF8890AA);
const _kBorder  = Color(0xFF252A40);
const _kBubbleMe    = Color(0xFF2D1B69);
const _kBubbleOther = Color(0xFF1C2035);

class MessageBubble extends StatefulWidget {
  final Message message;
  final UserModel? sender;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final Message? replyToMessage;
  final VoidCallback? onSwipeReply;
  final bool isSelected;
  final VoidCallback? onReplyTap;

  const MessageBubble({
    Key? key,
    required this.message,
    this.sender,
    required this.isMe,
    this.showAvatar = true,
    this.onLongPress,
    this.onTap,
    this.replyToMessage,
    this.onSwipeReply,
    this.isSelected = false,
    this.onReplyTap,
  }) : super(key: key);

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.15, 0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta! > 5) {
      _slideController.forward();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_slideController.value > 0.5) {
      widget.onSwipeReply?.call();
    }
    _slideController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: widget.isSelected ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.isSelected && !widget.isMe)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.check_circle, color: _kBrand, size: 24),
                  ),
                
                if (!widget.isMe && widget.showAvatar && !widget.isSelected) _buildAvatar(),
                if (!widget.isMe && !widget.showAvatar && !widget.isSelected) const SizedBox(width: 40),

                Flexible(
                  child: GestureDetector(
                    onTap: widget.onTap,
                    onLongPress: widget.onLongPress,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.isMe ? _kBubbleMe : _kBubbleOther,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
                          bottomRight: Radius.circular(widget.isMe ? 4 : 16),
                        ),
                        border: Border.all(
                          color: widget.isSelected
                              ? _kBrand
                              : (widget.isMe ? _kBrand.withOpacity(0.3) : _kBorder),
                          width: widget.isSelected ? 2 : 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.replyToMessage != null) _buildReplyPreview(context),
                          if (widget.message.messageType == 'image' && widget.message.mediaUrl != null)
                            _buildImageMessage(context)
                          else if (widget.message.messageType == 'video' && widget.message.mediaUrl != null)
                            _buildVideoMessage(context)
                          else if (widget.message.content != null)
                            _buildTextMessage(context),
                          const SizedBox(height: 4),
                          _buildMessageFooter(context),
                        ],
                      ),
                    ),
                  ),
                ),

                if (widget.isMe) const SizedBox(width: 8),
                
                if (widget.isSelected && widget.isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_circle, color: _kBrand, size: 24),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: _kBrand,
        backgroundImage: widget.sender?.profilePictureUrl != null
            ? NetworkImage(widget.sender!.profilePictureUrl!)
            : null,
        child: widget.sender?.profilePictureUrl == null
            ? Text(
                widget.sender?.displayName.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return GestureDetector(
      onTap: widget.onReplyTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: const Border(left: BorderSide(color: _kAccent, width: 3)),
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Replying to',
              style: TextStyle(fontSize: 12, color: _kAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.replyToMessage!.content ?? 'Media',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _kText2)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextMessage(BuildContext context) {
    final text = widget.message.content!;
    final isLong = text.length > 300;

    if (!isLong) {
      return _buildRichText(text);
    }

    final displayText = _isExpanded ? text : '${text.substring(0, 300)}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRichText(displayText),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Text(
            _isExpanded ? 'Show less' : 'Read more',
            style: const TextStyle(color: _kAccent, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildRichText(String text) {
    final urlRegex = RegExp(
      r'(https?://[^\s]+)|(www\.[^\s]+)',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return SelectableText(text,
        style: TextStyle(fontSize: 15, color: widget.isMe ? _kText1 : _kText1.withOpacity(0.9)));
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: const TextStyle(color: Color(0xFF60AAFF), decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: TextStyle(fontSize: 15, color: widget.isMe ? _kText1 : _kText1.withOpacity(0.9)),
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(widget.message.mediaUrl!, width: 200, fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(width: 200, height: 200, color: _kSurf2,
            child: const Center(child: CircularProgressIndicator(color: _kBrand)));
        },
        errorBuilder: (context, error, stack) {
          return Container(width: 200, height: 200, color: _kSurf2,
            child: const Icon(Icons.broken_image, size: 48, color: _kText2));
        },
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 200, height: 150,
          decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder)),
          child: const Icon(Icons.play_circle_outline, size: 64, color: _kAccent)),
      ],
    );
  }

  Widget _buildMessageFooter(BuildContext context) {
    final footerColor = widget.isMe ? _kText1.withOpacity(0.55) : _kText2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text('edited',
              style: TextStyle(fontSize: 11, color: footerColor, fontStyle: FontStyle.italic)),
          ),
        Text(DateUtil.formatMessageTime(widget.message.createdAt),
          style: TextStyle(fontSize: 11, color: footerColor)),
        if (widget.isMe) ...[
          const SizedBox(width: 4),
          _buildReadReceiptIcon(context),
        ],
      ],
    );
  }

  Widget _buildReadReceiptIcon(BuildContext context) {
    if (widget.message.isReadByAll) {
      return const Icon(Icons.done_all, size: 16, color: Color(0xFF60AAFF));
    } else if (widget.message.isDelivered) {
      return Icon(Icons.done_all, size: 16, color: _kText2);
    } else {
      return Icon(Icons.done, size: 16, color: _kText2);
    }
  }
}