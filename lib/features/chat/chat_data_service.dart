import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chatDataStorageKey = 'chat_data_v1';

class ChatData {
  const ChatData({
    required this.content,
    this.updatedAt,
  });

  final String content;
  final DateTime? updatedAt;

  bool get hasContent => content.trim().isNotEmpty;

  ChatData copyWith({
    String? content,
    DateTime? updatedAt,
  }) {
    return ChatData(
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ChatData.fromJson(Map<String, dynamic> json) {
    return ChatData(
      content: json['content'] as String? ?? '',
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

final chatDataProvider = AsyncNotifierProvider<ChatDataNotifier, ChatData>(
  ChatDataNotifier.new,
);

class ChatDataNotifier extends AsyncNotifier<ChatData> {
  @override
  Future<ChatData> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatDataStorageKey);
    if (raw == null || raw.isEmpty) return const ChatData(content: '');
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return ChatData.fromJson(decoded);
    } catch (_) {
      return const ChatData(content: '');
    }
  }

  Future<void> saveContent(String content) async {
    final next = ChatData(
      content: content,
      updatedAt: DateTime.now(),
    );
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatDataStorageKey, jsonEncode(next.toJson()));
  }

  Future<void> clear() => saveContent('');
}
