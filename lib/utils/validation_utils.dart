import 'app_constants.dart';
class ValidationUtils {
  static bool isValidMessage(String? content) {
    if (content == null || content.trim().isEmpty) return false;
    if (content.length > 5000) return false; // Max message length
    return true;
  }

  static bool isValidFileSize(int bytes, String fileType) {
    switch (fileType) {
      case 'image':
        return bytes <= AppConstants.maxImageSize;
      case 'video':
        return bytes <= AppConstants.maxVideoSize;
      case 'document':
        return bytes <= AppConstants.maxDocumentSize;
      default:
        return false;
    }
  }

  static bool isValidFileType(String extension, String fileType) {
    extension = extension.toLowerCase();
    switch (fileType) {
      case 'image':
        return AppConstants.allowedImageTypes.contains(extension);
      case 'video':
        return AppConstants.allowedVideoTypes.contains(extension);
      case 'document':
        return AppConstants.allowedDocTypes.contains(extension);
      default:
        return false;
    }
  }

  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return 'Invalid email format';
    return null;
  }

  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'Phone is required';
    final phoneRegex = RegExp(r'^\+?[1-9]\d{9,14}$');
    if (!phoneRegex.hasMatch(phone)) return 'Invalid phone number';
    return null;
  }

  static String sanitizeInput(String input) {
    // Remove potential XSS characters
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }
}