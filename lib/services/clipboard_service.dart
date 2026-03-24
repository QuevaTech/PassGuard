import 'dart:async';
import 'package:flutter/services.dart';

/// Singleton clipboard service with auto-clear.
/// All copy operations share a single timer — copying again cancels the
/// previous timer so the 30-second countdown always restarts from the last copy.
class ClipboardService {
  ClipboardService._();
  static final ClipboardService _instance = ClipboardService._();

  Timer? _clearTimer;
  static const _autoClearDuration = Duration(seconds: 30);

  Future<void> _copy(String text) async {
    _clearTimer?.cancel();
    await Clipboard.setData(ClipboardData(text: text));
    _clearTimer = Timer(_autoClearDuration, _clearSync);
  }

  void _clearSync() {
    Clipboard.setData(const ClipboardData(text: ''));
    _clearTimer = null;
  }

  // --- Static API (all existing call sites work unchanged) ---

  static Future<void> copyToClipboard(String text) => _instance._copy(text);

  static Future<void> copyPassword(String password, {Duration? autoClearDuration}) =>
      _instance._copy(password);

  static Future<void> copyUsername(String username, {Duration? autoClearDuration}) =>
      _instance._copy(username);

  static Future<void> copyWebsite(String website, {Duration? autoClearDuration}) =>
      _instance._copy(website);

  static Future<void> copyContent(String content, {Duration? autoClearDuration}) =>
      _instance._copy(content);

  static Future<void> clearClipboard() async {
    _instance._clearTimer?.cancel();
    _instance._clearTimer = null;
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  static Future<String> getFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text ?? '';
  }

  static Future<bool> hasText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text?.isNotEmpty ?? false;
  }
}
