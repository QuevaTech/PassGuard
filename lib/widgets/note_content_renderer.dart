import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/clipboard_service.dart';
import '../utils/app_localizations.dart';

/// Renders note content with support for [code]...[/code] and [spoiler]...[/spoiler] tags.
/// Plain text is rendered as normal Text.
/// Code blocks get a monospace container with a tap-to-copy button.
/// Spoiler blocks are blurred until tapped.
class NoteContentRenderer extends StatelessWidget {
  final String content;

  const NoteContentRenderer({super.key, required this.content});

  static final _tagPattern = RegExp(r'\[(code|spoiler)\]([\s\S]*?)\[/\1\]');

  List<_Segment> _parse(String text) {
    final segments = <_Segment>[];
    int lastEnd = 0;
    for (final match in _tagPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(_PlainSegment(text.substring(lastEnd, match.start)));
      }
      final tag = match.group(1)!;
      final body = match.group(2)!;
      if (tag == 'code') {
        segments.add(_CodeSegment(body));
      } else {
        segments.add(_SpoilerSegment(body));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      segments.add(_PlainSegment(text.substring(lastEnd)));
    }
    return segments.isEmpty ? [_PlainSegment(text)] : segments;
  }

  @override
  Widget build(BuildContext context) {
    final segments = _parse(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((seg) {
        if (seg is _CodeSegment) return _CodeBlock(text: seg.text);
        if (seg is _SpoilerSegment) return _SpoilerBlock(text: seg.text);
        return Text((seg as _PlainSegment).text, style: Theme.of(context).textTheme.bodyMedium);
      }).toList(),
    );
  }
}

/// Strips [code] and [spoiler] tags for plain-text clipboard copy.
String stripNoteTags(String content) =>
    content.replaceAll(RegExp(r'\[(code|spoiler)\]|\[/(code|spoiler)\]'), '');

// --- Segment types ---

abstract class _Segment {}
class _PlainSegment extends _Segment { final String text; _PlainSegment(this.text); }
class _CodeSegment extends _Segment  { final String text; _CodeSegment(this.text);  }
class _SpoilerSegment extends _Segment { final String text; _SpoilerSegment(this.text); }

// --- Code block widget ---

class _CodeBlock extends StatelessWidget {
  final String text;
  const _CodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3F55) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: SelectableText(
                text.trim(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                  height: 1.5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              onPressed: () {
                HapticFeedback.lightImpact();
                ClipboardService.copyContent(text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).codeCopied),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              tooltip: AppLocalizations.of(context).copy,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Spoiler block widget ---

class _SpoilerBlock extends StatefulWidget {
  final String text;
  const _SpoilerBlock({required this.text});

  @override
  State<_SpoilerBlock> createState() => _SpoilerBlockState();
}

class _SpoilerBlockState extends State<_SpoilerBlock> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _revealed = !_revealed);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _revealed ? Icons.visibility : Icons.visibility_off,
              size: 16,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _revealed
                  ? Text(
                      widget.text.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                      child: Text(
                        widget.text.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
