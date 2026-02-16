class EmojiUtil {
  static bool isOnlyEmojis(String text) {
    if (text.trim().isEmpty) return false;
    
    final emojiRegex = RegExp(
      r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
    );
    
    final withoutEmojis = text.replaceAll(emojiRegex, '').trim();
    return withoutEmojis.isEmpty;
  }

  static int getEmojiCount(String text) {
    if (!isOnlyEmojis(text)) return 0;
    
    final emojiRegex = RegExp(
      r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
    );
    
    return emojiRegex.allMatches(text).length;
  }

  static double getEmojiFontSize(String text) {
    if (!isOnlyEmojis(text)) return 16.0;
    
    final count = getEmojiCount(text);
    
    if (count == 1) return 40.0;
    if (count == 2) return 30.0;
    if (count == 3) return 25.0;
    
    return 16.0;
  }

  static bool shouldShowWithoutBubble(String text) {
    if (!isOnlyEmojis(text)) return false;
    return getEmojiCount(text) <= 3;
  }
}