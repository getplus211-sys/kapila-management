import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../screens/theme_provider.dart';

class ChatInputWidget extends StatefulWidget {
  final Function(String content, String type, {String? mediaPath}) onSendMessage;
  final Message? replyToMessage;
  final VoidCallback? onCancelReply;
  final VoidCallback? onTypingStart;
  final VoidCallback? onTypingStop;

  const ChatInputWidget({
    Key? key,
    required this.onSendMessage,
    this.replyToMessage,
    this.onCancelReply,
    this.onTypingStart,
    this.onTypingStop,
  }) : super(key: key);

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text, 'text');
    _controller.clear();
    setState(() => _isTyping = false);
    widget.onTypingStop?.call();
  }

  void _onTextChanged(String text) {
    final typing = text.trim().isNotEmpty;
    if (typing != _isTyping) {
      setState(() => _isTyping = typing);
      if (typing) { widget.onTypingStart?.call(); }
      else        { widget.onTypingStop?.call();  }
    } else if (typing) {
      widget.onTypingStart?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.3 : 0.08),
            blurRadius: 4, offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyToMessage != null) _buildReplyBar(t),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.add, color: t.text2),
                  onPressed: () {}, // TODO: media picker
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(color: t.text1),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(color: t.text2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: t.surface2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: _onTextChanged,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isTyping
                      ? IconButton(
                          key: const ValueKey('send'),
                          icon: const Icon(Icons.send),
                          color: t.brand,
                          onPressed: _sendMessage,
                        )
                      : IconButton(
                          key: const ValueKey('mic'),
                          icon: Icon(Icons.mic, color: t.text2),
                          onPressed: () {}, // TODO: voice recording
                        ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar(ThemeProvider t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border(left: BorderSide(color: t.brand, width: 3)),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Replying to',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.accent)),
            const SizedBox(height: 4),
            Text(
              widget.replyToMessage!.content ?? 'Media',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: t.text2),
            ),
          ],
        )),
        IconButton(
          icon: Icon(Icons.close, size: 20, color: t.text2),
          onPressed: widget.onCancelReply,
        ),
      ]),
    );
  }
}