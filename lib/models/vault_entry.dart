import 'package:flutter/material.dart' show Color;

enum VaultEntryType { password, note }

class VaultEntry {
  final String id;
  final VaultEntryType type;
  final String title;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Password fields (decrypted, in-memory only)
  final String? username;
  final String? password;
  final String? website;

  // Note fields (decrypted, in-memory only)
  final String? content;

  // Extra notes for any entry type (decrypted, in-memory only)
  final String? notes;

  // Non-sensitive metadata
  final bool isFavorite;

  /// ARGB color value for quick color tagging. Null means no color assigned.
  final int? colorValue;

  // Per-entry encryption metadata (stored in vault JSON)
  final String? encryptedData;
  final String? entryIv;
  final String? entryTag;

  VaultEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.username,
    this.password,
    this.website,
    this.content,
    this.notes,
    this.isFavorite = false,
    this.colorValue,
    this.encryptedData,
    this.entryIv,
    this.entryTag,
  });

  // Sentinel for copyWith to distinguish "not passed" from "explicitly null"
  static const Object _absent = Object();

  VaultEntry copyWith({
    String? id,
    VaultEntryType? type,
    String? title,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? username,
    String? password,
    String? website,
    String? content,
    String? notes,
    bool? isFavorite,
    Object? colorValue = _absent,
    String? encryptedData,
    String? entryIv,
    String? entryTag,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      password: password ?? this.password,
      website: website ?? this.website,
      content: content ?? this.content,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      colorValue: colorValue == _absent ? this.colorValue : colorValue as int?,
      encryptedData: encryptedData ?? this.encryptedData,
      entryIv: entryIv ?? this.entryIv,
      entryTag: entryTag ?? this.entryTag,
    );
  }

  /// Create from decrypted JSON (legacy format without per-entry encryption)
  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    return VaultEntry(
      id: json['id'] as String,
      type: (json['type'] as String) == 'password'
          ? VaultEntryType.password
          : VaultEntryType.note,
      title: json['title'] as String,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isFavorite: (json['is_favorite'] as bool?) ?? false,
      colorValue: json['color_value'] as int?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      website: json['website'] as String?,
      content: json['content'] as String?,
      notes: json['notes'] as String?,
      encryptedData: json['encrypted_data'] as String?,
      entryIv: json['entry_iv'] as String?,
      entryTag: json['entry_tag'] as String?,
    );
  }

  /// Serialize to JSON for vault storage (encrypted format).
  /// Sensitive fields are NOT included here — they go into encrypted_data.
  Map<String, dynamic> toEncryptedJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_favorite': isFavorite,
      if (colorValue != null) 'color_value': colorValue,
      if (encryptedData != null) 'encrypted_data': encryptedData,
      if (entryIv != null) 'entry_iv': entryIv,
      if (entryTag != null) 'entry_tag': entryTag,
    };
  }

  /// Serialize to legacy JSON — sensitive fields in plaintext.
  /// @deprecated Use [toEncryptedJson] + per-entry encryption instead.
  /// Only kept for backward-compatibility with v1/v2 vault migration paths.
  @Deprecated('Use toEncryptedJson() — this method exposes sensitive fields in plaintext')
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (colorValue != null) 'color_value': colorValue,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (website != null) 'website': website,
      if (content != null) 'content': content,
    };
  }

  /// Get the sensitive fields as a JSON map (for encryption)
  Map<String, dynamic> getSensitiveFields() {
    final fields = <String, dynamic>{};
    if (username != null) fields['username'] = username;
    if (password != null) fields['password'] = password;
    if (website != null) fields['website'] = website;
    if (content != null) fields['content'] = content;
    if (notes != null) fields['notes'] = notes;
    return fields;
  }

  /// Check if this entry has per-entry encryption
  bool get isEntryEncrypted =>
      encryptedData != null && entryIv != null && entryTag != null;

  /// The tag color for this entry, or null if none assigned.
  Color? get color => colorValue != null ? Color(colorValue!) : null;

  String get displayTitle => title.isNotEmpty ? title : 'Untitled';
  String get displayCategory => category.isNotEmpty ? category : 'Other';

  // Maximum field sizes — prevents memory exhaustion during encryption/ZIP.
  static const int maxSensitiveFieldLength = 10 * 1024 * 1024; // 10 MB per field
  static const int maxTitleLength = 512;
  static const int maxCategoryLength = 256;

  /// Throws [ArgumentError] if any field exceeds the allowed size.
  /// Call this before saving/encrypting an entry.
  void validate() {
    if (title.length > maxTitleLength) {
      throw ArgumentError('Title exceeds maximum length of $maxTitleLength characters.');
    }
    if (category.length > maxCategoryLength) {
      throw ArgumentError('Category exceeds maximum length of $maxCategoryLength characters.');
    }
    if ((password?.length ?? 0) > maxSensitiveFieldLength) {
      throw ArgumentError('Password field exceeds maximum size of 10 MB.');
    }
    if ((notes?.length ?? 0) > maxSensitiveFieldLength) {
      throw ArgumentError('Notes field exceeds maximum size of 10 MB.');
    }
    if ((content?.length ?? 0) > maxSensitiveFieldLength) {
      throw ArgumentError('Content field exceeds maximum size of 10 MB.');
    }
    if ((username?.length ?? 0) > maxSensitiveFieldLength) {
      throw ArgumentError('Username field exceeds maximum size of 10 MB.');
    }
    if ((website?.length ?? 0) > maxSensitiveFieldLength) {
      throw ArgumentError('Website field exceeds maximum size of 10 MB.');
    }
  }
}
