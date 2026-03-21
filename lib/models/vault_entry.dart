import 'package:flutter/foundation.dart';

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
    this.encryptedData,
    this.entryIv,
    this.entryTag,
  });

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
      username: json['username'] as String?,
      password: json['password'] as String?,
      website: json['website'] as String?,
      content: json['content'] as String?,
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
      if (encryptedData != null) 'encrypted_data': encryptedData,
      if (entryIv != null) 'entry_iv': entryIv,
      if (entryTag != null) 'entry_tag': entryTag,
    };
  }

  /// Serialize to legacy JSON (plaintext sensitive fields — for backward compat only)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
    return fields;
  }

  /// Check if this entry has per-entry encryption
  bool get isEntryEncrypted =>
      encryptedData != null && entryIv != null && entryTag != null;

  String get displayTitle => title.isNotEmpty ? title : 'Untitled';
  String get displayCategory => category.isNotEmpty ? category : 'Other';
}
