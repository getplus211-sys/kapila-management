import 'package:intl/intl.dart';

class DateUtil {
  static String formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    // Under 24 hours - show time
    if (diff.inHours < 24) {
      return DateFormat('HH:mm').format(dateTime);
    }
    
    // Same year - show date + time
    if (dateTime.year == now.year) {
      return DateFormat('dd MMM, HH:mm').format(dateTime);
    }
    
    // Different year - full date + time
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  static String formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Long time ago';
    
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    
    if (diff.inSeconds < 30) return 'Last seen recently';
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes == 1) return 'Last seen 1 minute ago';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes} minutes ago';
    if (diff.inHours == 1) return 'Last seen 1 hour ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Last seen yesterday';
    if (diff.inDays < 7) return 'Last seen ${diff.inDays} days ago';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'Last seen $weeks week${weeks > 1 ? 's' : ''} ago';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return 'Last seen $months month${months > 1 ? 's' : ''} ago';
    }
    final years = (diff.inDays / 365).floor();
    return 'Last seen $years year${years > 1 ? 's' : ''} ago';
  }

  static String getDateDivider(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return 'TODAY';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'YESTERDAY';
    } else {
      return DateFormat('dd MMMM yyyy').format(dateTime).toUpperCase();
    }
  }

  static bool shouldShowDateDivider(DateTime? previousDate, DateTime currentDate) {
    if (previousDate == null) return true;
    
    final prevDay = DateTime(previousDate.year, previousDate.month, previousDate.day);
    final currDay = DateTime(currentDate.year, currentDate.month, currentDate.day);
    
    return prevDay != currDay;
  }
}