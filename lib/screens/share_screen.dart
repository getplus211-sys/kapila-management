import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_item.dart';
import '../models/chat_model.dart';
import '../services/local_storage_service.dart';

const _kBg      = Color(0xFF0B0E1A);
const _kSurface = Color(0xFF141828);
const _kSurf2   = Color(0xFF1C2035);
const _kBrand   = Color(0xFF7B4FD6);
const _kAccent  = Color(0xFF9B6FF0);
const _kText1   = Color(0xFFEEEEF5);
const _kText2   = Color(0xFF8890AA);
const _kBorder  = Color(0xFF252A40);

class ShareContent {
  final String? text;
  final String? imageUrl;
  final String? videoUrl;
  final String? fileUrl;
  final String? link;
  final String type;

  ShareContent({
    this.text, this.imageUrl, this.videoUrl,
    this.fileUrl, this.link, required this.type,
  });

  String get displayText {
    switch (type) {
      case 'text':  return text ?? '';
      case 'image': return '📷 Image';
      case 'video': return '🎥 Video';
      case 'file':  return '📄 File';
      case 'link':  return '🔗 ${link ?? ''}';
      default:      return '';
    }
  }
}

void showShareSheet(BuildContext context, ShareContent content) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ShareBottomSheet(content: content),
  );
}

class ShareBottomSheet extends StatefulWidget {
  final ShareContent content;
  const ShareBottomSheet({super.key, required this.content});

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final _supabase = Supabase.instance.client;
  final _storage = LocalStorageService();
  final _searchController = TextEditingController();

  List<ChatItem> _recentChats = [];
  List<Map<String, dynamic>> _contacts = [];
  List<ChatItem> _groups = [];
  List<ChatItem> _channels = [];

  List<String> _selectedIds = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _selectedTab = 0;

  @override
  void initState() { super.initState(); _loadData(); }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final cachedChats = _storage.getCachedChatList();
      if (cachedChats != null) {
        final chats = cachedChats.map((c) => ChatItem(
          chatId: c['chatId'],
          chatType: ChatType.values.firstWhere((e) => e.toString() == c['chatType']),
          name: c['name'], avatarUrl: c['avatarUrl'],
          lastMessage: c['lastMessage'] ?? '',
          lastMessageTime: DateTime.parse(c['lastMessageTime']),
          unreadCount: c['unreadCount'] ?? 0, isPinned: false, isMuted: false,
        )).toList();

        setState(() {
          _recentChats = chats.where((c) =>
            c.chatType == ChatType.private && c.chatId != 'saved_messages').toList();
          _groups   = chats.where((c) => c.chatType == ChatType.group).toList();
          _channels = chats.where((c) => c.chatType == ChatType.channel).toList();
        });
      }

      final cachedContacts = _storage.getCachedContacts();
      if (cachedContacts != null) {
        setState(() {
          // ✅ FIX: Map<dynamic,dynamic> → Map<String,dynamic>
          _contacts = cachedContacts
              .where((c) => c['isRegistered'] == true)
              .map((c) => Map<String, dynamic>.from(c))
              .toList();
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading share data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length < 5) {
          _selectedIds.add(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 chats can be selected')));
        }
      }
    });
  }

  Future<void> _sendToSelected() async {
    if (_selectedIds.isEmpty) return;
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Sending to ${_selectedIds.length} chat(s)...'),
          ]),
          duration: const Duration(seconds: 2),
        ),
      );

      for (final chatId in _selectedIds) { await _sendToChat(chatId, userId); }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Sent successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) { debugPrint('Error sending: $e'); }
  }

  Future<void> _sendToChat(String chatId, String userId) async {
    String messageType = widget.content.type;
    String? content;
    String? mediaUrl;

    switch (widget.content.type) {
      case 'text':
        content = widget.content.text;
        messageType = 'text';
        break;
      case 'link':
        content = widget.content.link;
        messageType = 'text';
        break;
      case 'image':
        mediaUrl = widget.content.imageUrl;
        messageType = 'image';
        break;
      case 'video':
        mediaUrl = widget.content.videoUrl;
        messageType = 'video';
        break;
      case 'file':
        mediaUrl = widget.content.fileUrl;
        messageType = 'file';
        break;
    }

    await _supabase.from('ngm_messages').insert({
      'chat_id': chatId, 'sender_id': userId,
      'message_type': messageType, 'content': content,
      'media_url': mediaUrl, 'created_at': DateTime.now().toIso8601String(),
    });

    await _supabase.from('ngm_chats').update({
      'last_message_at': DateTime.now().toIso8601String(),
      'last_message_by': userId,
    }).eq('chat_id', chatId);
  }

  void _copyToClipboard() {
    final text = widget.content.text ?? widget.content.link ?? '';
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Copied to clipboard!'), backgroundColor: Colors.green));
  }

  Future<void> _shareToWhatsApp() async {
    final text = Uri.encodeComponent(
      widget.content.text ?? widget.content.link ?? widget.content.displayText);
    final url = 'whatsapp://send?text=$text';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp not installed')));
      }
    } catch (e) { debugPrint('WhatsApp error: $e'); }
  }

  Future<void> _shareToTelegram() async {
    final text = Uri.encodeComponent(
      widget.content.text ?? widget.content.link ?? widget.content.displayText);
    final url = 'tg://msg?text=$text';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telegram not installed')));
      }
    } catch (e) { debugPrint('Telegram error: $e'); }
  }

  List<dynamic> get _filteredItems {
    List<dynamic> items = [];
    switch (_selectedTab) {
      case 0: items = _recentChats; break;
      case 1: items = _contacts; break;
      case 2: items = _groups; break;
      case 3: items = _channels; break;
    }
    if (_searchQuery.isEmpty) return items;
    return items.where((item) {
      if (item is ChatItem) return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (item is Map)      return (item['contactName'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [

          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('Share to',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kText1)),
              const Spacer(),
              if (_selectedIds.isNotEmpty)
                ElevatedButton(
                  onPressed: _sendToSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: Text('Send (${_selectedIds.length})'),
                ),
            ]),
          ),

          const SizedBox(height: 12),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kSurf2, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kBrand.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(_getContentIcon(), color: _kBrand, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.content.displayText,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _kText1, fontSize: 13))),
            ]),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _buildExternalApp(icon: '📱', label: 'WhatsApp',
                color: const Color(0xFF25D366), onTap: _shareToWhatsApp),
              const SizedBox(width: 12),
              _buildExternalApp(icon: '✈️', label: 'Telegram',
                color: const Color(0xFF0088CC), onTap: _shareToTelegram),
              const SizedBox(width: 12),
              _buildExternalApp(icon: '📋', label: 'Copy Link',
                color: _kAccent, onTap: _copyToClipboard),
            ]),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: _kText1),
              decoration: InputDecoration(
                hintText: 'Search...', hintStyle: const TextStyle(color: _kText2),
                prefixIcon: const Icon(Icons.search, color: _kText2),
                filled: true, fillColor: _kSurf2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: _kSurf2, borderRadius: BorderRadius.circular(25)),
            child: Row(children: [
              _buildTab(0, 'Recent'),
              _buildTab(1, 'Contacts'),
              _buildTab(2, 'Groups'),
              _buildTab(3, 'Channels'),
            ]),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kBrand))
                : _filteredItems.isEmpty
                    ? Center(child: Text(
                        'No ${['chats','contacts','groups','channels'][_selectedTab]} found',
                        style: const TextStyle(color: _kText2)))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          if (item is ChatItem) return _buildChatTile(item);
                          // ✅ FIX: Map cast
                          if (item is Map)      return _buildContactTile(Map<String, dynamic>.from(item));
                          return const SizedBox.shrink();
                        }),
          ),
        ]),
      ),
    );
  }

  Widget _buildExternalApp({required String icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3))),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _kBrand : Colors.transparent,
            borderRadius: BorderRadius.circular(20)),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? Colors.white : _kText2)),
        ),
      ),
    );
  }

  Widget _buildChatTile(ChatItem chat) {
    final isSelected = _selectedIds.contains(chat.chatId);
    return ListTile(
      leading: Stack(children: [
        CircleAvatar(
          backgroundColor: _kBrand,
          backgroundImage: chat.avatarUrl != null ? NetworkImage(chat.avatarUrl!) : null,
          child: chat.avatarUrl == null
              ? Text(chat.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)) : null),
        if (isSelected)
          Positioned.fill(child: Container(
            decoration: BoxDecoration(color: _kBrand.withOpacity(0.7), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 20))),
      ]),
      title: Text(chat.name, style: const TextStyle(color: _kText1, fontWeight: FontWeight.w600)),
      subtitle: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _kText2, fontSize: 12)),
      onTap: () => _toggleSelect(chat.chatId),
      tileColor: isSelected ? _kBrand.withOpacity(0.1) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildContactTile(Map<String, dynamic> contact) {
    final contactId = contact['userId'] ?? '';
    final isSelected = _selectedIds.contains(contactId);
    final name = contact['contactName'] ?? contact['fullName'] ?? 'Unknown';
    final avatarUrl = contact['profilePictureUrl'];

    return ListTile(
      leading: Stack(children: [
        CircleAvatar(
          backgroundColor: _kBrand,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)) : null),
        if (isSelected)
          Positioned.fill(child: Container(
            decoration: BoxDecoration(color: _kBrand.withOpacity(0.7), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 20))),
      ]),
      title: Text(name, style: const TextStyle(color: _kText1, fontWeight: FontWeight.w600)),
      subtitle: Text('@${contact['username'] ?? ''}',
          style: const TextStyle(color: _kText2, fontSize: 12)),
      onTap: () async {
        if (contactId.isEmpty) return;
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) return;
        try {
          final existing = await _supabase.from('ngm_chats').select('chat_id')
              .or('and(user1_id.eq.$userId,user2_id.eq.$contactId),and(user1_id.eq.$contactId,user2_id.eq.$userId)')
              .eq('chat_type', 'private').maybeSingle();
          String chatId;
          if (existing != null) {
            chatId = existing['chat_id'];
          } else {
            final chat = await _supabase.from('ngm_chats').insert({
              'chat_type': 'private', 'user1_id': userId, 'user2_id': contactId,
              'created_at': DateTime.now().toIso8601String(),
            }).select().single();
            chatId = chat['chat_id'];
            await _supabase.from('ngm_chat_participants').insert([
              {'chat_id': chatId, 'user_id': userId, 'is_active': true, 'unread_count': 0},
              {'chat_id': chatId, 'user_id': contactId, 'is_active': true, 'unread_count': 0},
            ]);
          }
          _toggleSelect(chatId);
        } catch (e) { debugPrint('Error: $e'); }
      },
      tileColor: isSelected ? _kBrand.withOpacity(0.1) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  IconData _getContentIcon() {
    switch (widget.content.type) {
      case 'image': return Icons.image;
      case 'video': return Icons.videocam;
      case 'file':  return Icons.insert_drive_file;
      case 'link':  return Icons.link;
      default:      return Icons.text_fields;
    }
  }
}