class AppConstants {
  // Error Messages
  static const String networkError = 'No internet connection';
  static const String serverError = 'Server error occurred';
  static const String authError = 'Authentication failed';
  static const String uploadError = 'Failed to upload file';
  
  // File Limits
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB
  static const int maxDocumentSize = 10 * 1024 * 1024; // 10MB
  
  // Pagination
  static const int messagesPerPage = 20;
  static const int chatsPerPage = 20;
  
  // Timeouts
  static const Duration uploadTimeout = Duration(minutes: 5);
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration typingDebounce = Duration(seconds: 2);
  
  // Cache
  static const Duration cacheExpiry = Duration(hours: 24);
  static const int maxCachedMessages = 500;
  
  // Allowed file types
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
  static const List<String> allowedVideoTypes = ['mp4', 'mov', 'avi'];
  static const List<String> allowedDocTypes = ['pdf', 'doc', 'docx', 'txt'];
}