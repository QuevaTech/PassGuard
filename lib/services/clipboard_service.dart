import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Singleton clipboard service with auto-clear and lifecycle-aware clearing.
///
/// - Copies share a single timer — copying again resets the 30-second countdown.
/// - Clipboard is cleared immediately when the app enters the background (paused
///   or hidden), so sensitive values don't linger while the app is not visible.
class ClipboardService with WidgetsBindingObserver {
  ClipboardService._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final ClipboardService _instance = ClipboardService._();

  Timer? _clearTimer;
  static const _autoClearDuration = Duration(seconds: 30);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _clearTimer?.cancel();
      _clearTimer = null;
      Clipboard.setData(const ClipboardData(text: ''));
    }
  }

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

  static Future<void> copyPassword(String password) => _instance._copy(password);

  static Future<void> copyUsername(String username) => _instance._copy(username);

  static Future<void> copyWebsite(String website) => _instance._copy(website);

  static Future<void> copyContent(String content) => _instance._copy(content);

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
