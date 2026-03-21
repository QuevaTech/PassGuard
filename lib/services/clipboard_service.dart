import 'package:flutter/services.dart';

class ClipboardService {
  // Copy text to clipboard
  static Future<void> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      throw Exception('Failed to copy to clipboard: $e');
    }
  }

  // Get text from clipboard
  static Future<String> getFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text ?? '';
    } catch (e) {
      throw Exception('Failed to get from clipboard: $e');
    }
  }

  // Clear clipboard
  static Future<void> clearClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: ''));
    } catch (e) {
      throw Exception('Failed to clear clipboard: $e');
    }
  }

  // Copy password with auto-clear
  static Future<void> copyPassword(String password, {Duration? autoClearDuration}) async {
    try {
      await copyToClipboard(password);
      
      // Auto-clear after specified duration (default 10 seconds)
      final duration = autoClearDuration ?? Duration(seconds: 10);
      Future.delayed(duration, () async {
        try {
          await clearClipboard();
        } catch (e) {
          // Ignore auto-clear errors
        }
      });
    } catch (e) {
      throw Exception('Failed to copy password: $e');
    }
  }

  // Copy username with auto-clear
  static Future<void> copyUsername(String username, {Duration? autoClearDuration}) async {
    try {
      await copyToClipboard(username);
      
      // Auto-clear after specified duration (default 10 seconds)
      final duration = autoClearDuration ?? Duration(seconds: 10);
      Future.delayed(duration, () async {
        try {
          await clearClipboard();
        } catch (e) {
          // Ignore auto-clear errors
        }
      });
    } catch (e) {
      throw Exception('Failed to copy username: $e');
    }
  }

  // Copy website with auto-clear
  static Future<void> copyWebsite(String website, {Duration? autoClearDuration}) async {
    try {
      await copyToClipboard(website);
      
      // Auto-clear after specified duration (default 10 seconds)
      final duration = autoClearDuration ?? Duration(seconds: 10);
      Future.delayed(duration, () async {
        try {
          await clearClipboard();
        } catch (e) {
          // Ignore auto-clear errors
        }
      });
    } catch (e) {
      throw Exception('Failed to copy website: $e');
    }
  }

  // Copy note content with auto-clear
  static Future<void> copyContent(String content, {Duration? autoClearDuration}) async {
    try {
      await copyToClipboard(content);
      
      // Auto-clear after specified duration (default 30 seconds for notes)
      final duration = autoClearDuration ?? Duration(seconds: 30);
      Future.delayed(duration, () async {
        try {
          await clearClipboard();
        } catch (e) {
          // Ignore auto-clear errors
        }
      });
    } catch (e) {
      throw Exception('Failed to copy content: $e');
    }
  }

  // Check if clipboard has text
  static Future<bool> hasText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text?.isNotEmpty ?? false;
    } catch (e) {
      return false;
    }
  }

  // Get clipboard text length
  static Future<int> getTextLength() async {
    try {
      final text = await getFromClipboard();
      return text.length;
    } catch (e) {
      return 0;
    }
  }

  // Copy multiple items (for debugging/testing)
  static Future<void> copyMultiple(Map<String, String> items) async {
    try {
      for (final entry in items.entries) {
        await copyToClipboard(entry.value);
        // Small delay between copies
        await Future.delayed(Duration(milliseconds: 100));
      }
    } catch (e) {
      throw Exception('Failed to copy multiple items: $e');
    }
  }
}