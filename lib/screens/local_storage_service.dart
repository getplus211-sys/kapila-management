import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;
  
  // Hive box names
  static const String messagesBox = 'messages';
  static const String usersBox = 'users';
  static const String chatsBox = 'chats';
  
  Future<void> init() async {
    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize Hive
    await Hive.initFlutter();
    
    // Register adapters (commented out - uncomment after running build_runner)
    // Hive.registerAdapter(MessageAdapter());
    // Hive.registerAdapter(UserModelAdapter());
    // Hive.registerAdapter(ChatModelAdapter());
    
    // Open boxes
    await Hive.openBox<Message>(messagesBox);
    await Hive.openBox<UserModel>(usersBox);
    await Hive.openBox<ChatModel>(chatsBox);
  }

  // ==================== HIVE OPERATIONS (For Messages) ====================
  
  // Message operations
  Future<void> saveMessage(Message message) async {
    final box = Hive.box<Message>(messagesBox);
    await box.put(message.messageId, message);
  }

  Future<void> saveMessages(List<Message> messages) async {
    final box = Hive.box<Message>(messagesBox);
    for (var message in messages) {
      await box.put(message.messageId, message);
    }
  }

  List<Message> getMessagesByChat(String chatId) {
    final box = Hive.box<Message>(messagesBox);
    return box.values
        .where((msg) => msg.chatId == chatId && !msg.isDeletedForMe)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Message? getMessage(String messageId) {
    final box = Hive.box<Message>(messagesBox);
    return box.get(messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    final box = Hive.box<Message>(messagesBox);
    await box.delete(messageId);
  }

  Future<void> updateMessage(Message message) async {
    final box = Hive.box<Message>(messagesBox);
    await box.put(message.messageId, message);
  }

  Future<void> markMessageAsDeletedForMe(String messageId) async {
    final box = Hive.box<Message>(messagesBox);
    final message = box.get(messageId);
    if (message != null) {
      await box.put(
        messageId,
        message.copyWith(isDeletedForMe: true),
      );
    }
  }

  // User operations
  Future<void> saveUser(UserModel user) async {
    final box = Hive.box<UserModel>(usersBox);
    await box.put(user.userId, user);
  }

  UserModel? getUser(String userId) {
    final box = Hive.box<UserModel>(usersBox);
    return box.get(userId);
  }

  // Chat operations
  Future<void> saveChat(ChatModel chat) async {
    final box = Hive.box<ChatModel>(chatsBox);
    await box.put(chat.chatId, chat);
  }

  ChatModel? getChat(String chatId) {
    final box = Hive.box<ChatModel>(chatsBox);
    return box.get(chatId);
  }

  Future<void> updateChat(ChatModel chat) async {
    final box = Hive.box<ChatModel>(chatsBox);
    await box.put(chat.chatId, chat);
  }

  List<ChatModel> getAllChats() {
    final box = Hive.box<ChatModel>(chatsBox);
    return box.values.toList()
      ..sort((a, b) => (b.lastMessageAt ?? b.updatedAt)
          .compareTo(a.lastMessageAt ?? a.updatedAt));
  }

  // ==================== SHARED PREFERENCES OPERATIONS ====================

  // Chat List Cache
  Future<void> saveChatList(List<Map<String, dynamic>> chats) async {
    await _prefs?.setString('cached_chats', jsonEncode(chats));
  }

  List<Map<String, dynamic>>? getCachedChatList() {
    final data = _prefs?.getString('cached_chats');
    if (data == null) return null;
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      return null;
    }
  }

  // Contacts Cache
  Future<void> saveContacts(List<Map<String, dynamic>> contacts) async {
    await _prefs?.setString('cached_contacts', jsonEncode(contacts));
  }

  List<Map<String, dynamic>>? getCachedContacts() {
    final data = _prefs?.getString('cached_contacts');
    if (data == null) return null;
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      return null;
    }
  }

  // Messages Cache (JSON format for compatibility)
  Future<void> saveChatMessages(String chatId, List<Map<String, dynamic>> messages) async {
    await _prefs?.setString('messages_$chatId', jsonEncode(messages));
  }

  List<Map<String, dynamic>>? getCachedMessages(String chatId) {
    final data = _prefs?.getString('messages_$chatId');
    if (data == null) return null;
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      return null;
    }
  }

  Future<void> clearChatMessages(String chatId) async {
    await _prefs?.remove('messages_$chatId');
  }

  // Typing Draft
  Future<void> saveDraft(String chatId, String text) async {
    if (text.isEmpty) {
      await _prefs?.remove('draft_$chatId');
    } else {
      await _prefs?.setString('draft_$chatId', text);
    }
  }

  String? getDraft(String chatId) {
    return _prefs?.getString('draft_$chatId');
  }

  // Auto-download Settings
  Future<void> saveAutoDownloadSettings({
    required bool wifi,
    required bool mobile,
    required bool roaming,
  }) async {
    await _prefs?.setBool('auto_download_wifi', wifi);
    await _prefs?.setBool('auto_download_mobile', mobile);
    await _prefs?.setBool('auto_download_roaming', roaming);
  }

  Map<String, bool> getAutoDownloadSettings() {
    return {
      'wifi': _prefs?.getBool('auto_download_wifi') ?? true,
      'mobile': _prefs?.getBool('auto_download_mobile') ?? false,
      'roaming': _prefs?.getBool('auto_download_roaming') ?? false,
    };
  }

  // Pinned Chats
  Future<void> savePinnedChats(List<String> chatIds) async {
    await _prefs?.setStringList('pinned_chats', chatIds);
  }

  List<String> getPinnedChats() {
    return _prefs?.getStringList('pinned_chats') ?? [];
  }

  Future<void> pinChat(String chatId) async {
    final pinned = getPinnedChats();
    if (!pinned.contains(chatId)) {
      pinned.insert(0, chatId);
      await savePinnedChats(pinned);
    }
  }

  Future<void> unpinChat(String chatId) async {
    final pinned = getPinnedChats();
    pinned.remove(chatId);
    await savePinnedChats(pinned);
  }

  bool isChatPinned(String chatId) {
    return getPinnedChats().contains(chatId);
  }

  // Archived Chats
  Future<void> saveArchivedChats(List<String> chatIds) async {
    await _prefs?.setStringList('archived_chats', chatIds);
  }

  List<String> getArchivedChats() {
    return _prefs?.getStringList('archived_chats') ?? [];
  }

  Future<void> archiveChat(String chatId) async {
    final archived = getArchivedChats();
    if (!archived.contains(chatId)) {
      archived.add(chatId);
      await saveArchivedChats(archived);
    }
  }

  Future<void> unarchiveChat(String chatId) async {
    final archived = getArchivedChats();
    archived.remove(chatId);
    await saveArchivedChats(archived);
  }

  bool isChatArchived(String chatId) {
    return getArchivedChats().contains(chatId);
  }

  // Last Refresh
  Future<void> saveLastRefreshTime() async {
    await _prefs?.setInt('last_refresh', DateTime.now().millisecondsSinceEpoch);
  }

  DateTime? getLastRefreshTime() {
    final timestamp = _prefs?.getInt('last_refresh');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // ==================== CLEAR OPERATIONS ====================

  // Clear SharedPreferences cache
  Future<void> clearCache() async {
    await _prefs?.remove('cached_chats');
    await _prefs?.remove('cached_contacts');
    await saveLastRefreshTime();
  }

  // Clear all SharedPreferences
  Future<void> clearAllPreferences() async {
    await _prefs?.clear();
  }

  // Clear all Hive data
  Future<void> clearAllHive() async {
    await Hive.box<Message>(messagesBox).clear();
    await Hive.box<UserModel>(usersBox).clear();
    await Hive.box<ChatModel>(chatsBox).clear();
  }

  // Clear everything
  Future<void> clearAll() async {
    await clearAllPreferences();
    await clearAllHive();
  }
}