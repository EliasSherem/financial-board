import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../widgets/pro_widgets.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatSession> _sessions = [];
  String? _activeSessionId;
  bool _loading = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadSessions();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _legacyHistoryKey(int? userId) => 'ai_chat_history_${userId ?? 'anon'}';
  String _sessionsKey(int? userId) => 'ai_chat_sessions_${userId ?? 'anon'}';
  String _activeSessionKey(int? userId) => 'ai_chat_active_${userId ?? 'anon'}';

  Future<void> _loadSessions() async {
    final userId = context.read<AuthStore>().userId;
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_sessionsKey(userId));
    final storedActiveId = sp.getString(_activeSessionKey(userId));
    bool dirty = false;
    List<_ChatSession> sessions = [];

    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        sessions =
            list
                .whereType<Map>()
                .map((e) => _ChatSession.fromJson(e.cast<String, dynamic>()))
                .whereType<_ChatSession>()
                .toList();
      } catch (_) {}
    } else {
      final legacyRaw = sp.getString(_legacyHistoryKey(userId));
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        try {
          final list = jsonDecode(legacyRaw) as List<dynamic>;
          final legacyMessages =
              list
                  .whereType<Map>()
                  .map((e) => _ChatMessage.fromJson(e.cast<String, dynamic>()))
                  .whereType<_ChatMessage>()
                  .toList();
          if (legacyMessages.isNotEmpty) {
            sessions.add(
              _ChatSession(
                id: _newSessionId(),
                title: '',
                messages: legacyMessages,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
          }
          await sp.remove(_legacyHistoryKey(userId));
          dirty = true;
        } catch (_) {}
      }
    }

    if (sessions.isEmpty) {
      sessions.add(_createSession());
      dirty = true;
    }

    var activeId = storedActiveId;
    if (activeId == null || !sessions.any((s) => s.id == activeId)) {
      activeId = sessions.first.id;
      dirty = true;
    }

    if (!mounted) return;
    setState(() {
      _sessions
        ..clear()
        ..addAll(sessions);
      _activeSessionId = activeId;
    });
    if (dirty) {
      await _saveSessions();
    }
  }

  Future<void> _saveSessions() async {
    final userId = context.read<AuthStore>().userId;
    final sp = await SharedPreferences.getInstance();
    final payload = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await sp.setString(_sessionsKey(userId), payload);
    if (_activeSessionId != null) {
      await sp.setString(_activeSessionKey(userId), _activeSessionId!);
    } else {
      await sp.remove(_activeSessionKey(userId));
    }
  }

  String _newSessionId() => DateTime.now().microsecondsSinceEpoch.toString();

  _ChatSession _createSession() {
    return _ChatSession(
      id: _newSessionId(),
      title: '',
      messages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  _ChatSession? _findSession(String id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  _ChatSession _ensureActiveSession() {
    final active = _activeSessionId != null ? _findSession(_activeSessionId!) : null;
    if (active != null) return active;
    if (_sessions.isNotEmpty) {
      _activeSessionId = _sessions.first.id;
      return _sessions.first;
    }
    final created = _createSession();
    _sessions.add(created);
    _activeSessionId = created.id;
    return created;
  }

  String _truncateTitle(String text) {
    final trimmed = text.replaceAll('\n', ' ').trim();
    if (trimmed.length <= 36) return trimmed;
    return '${trimmed.substring(0, 36)}...';
  }

  Future<void> _send() async {
    if (_loading) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final session = _ensureActiveSession();
    final sessionId = session.id;

    setState(() {
      session.messages.add(_ChatMessage(role: 'user', content: text));
      if (session.messages.length == 1) {
        session.title = _truncateTitle(text);
      }
      session.updatedAt = DateTime.now();
      _loading = true;
    });
    _inputCtrl.clear();
    await _saveSessions();
    if (_activeSessionId == sessionId) {
      _scrollToBottom();
    }

    final auth = context.read<AuthStore>();
    final api = ApiClient()..setToken(auth.token);
    final data = DataService(api);
    final payload =
        session.messages
            .map((m) => m.toJson())
            .toList()
            .cast<Map<String, String>>();
    final trimmed =
        payload.length > 20 ? payload.sublist(payload.length - 20) : payload;

    try {
      final reply = await data.aiChat(messages: trimmed);
      if (mounted) {
        setState(() {
          final target = _findSession(sessionId);
          if (target != null) {
            target.messages.add(
              _ChatMessage(
                role: 'assistant',
                content: reply.isEmpty ? I18n.t(context, 'aiChat.empty') : reply,
              ),
            );
            target.updatedAt = DateTime.now();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${I18n.t(context, 'label.failed')}: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        await _saveSessions();
        if (_activeSessionId == sessionId) {
          _scrollToBottom();
        }
      }
    }
  }

  Future<void> _createNewChat() async {
    if (_loading) return;
    final session = _createSession();
    setState(() {
      _sessions.insert(0, session);
      _activeSessionId = session.id;
    });
    await _saveSessions();
  }

  Future<void> _selectSession(_ChatSession session) async {
    setState(() => _activeSessionId = session.id);
    await _saveSessions();
    _scrollToBottom();
  }

  Future<bool> _deleteSession(_ChatSession session) async {
    if (_loading && session.id == _activeSessionId) return false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(I18n.t(ctx, 'aiChat.deleteTitle')),
          content: Text(I18n.t(ctx, 'aiChat.deleteBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(I18n.t(ctx, 'label.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(I18n.t(ctx, 'label.delete')),
            ),
          ],
        );
      },
    );
    if (confirm != true) return false;

    setState(() {
      _sessions.removeWhere((s) => s.id == session.id);
      if (_sessions.isEmpty) {
        final created = _createSession();
        _sessions.add(created);
        _activeSessionId = created.id;
      } else if (_activeSessionId == session.id) {
        _activeSessionId = _sessions.first.id;
      }
    });
    await _saveSessions();
    return true;
  }

  Future<void> _openChatList() async {
    if (_sessions.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final sessions = List<_ChatSession>.from(_sessions)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final maxHeight = MediaQuery.of(ctx).size.height * 0.6;
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          I18n.t(ctx, 'aiChat.chats'),
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _loading
                            ? null
                            : () async {
                                Navigator.of(ctx).pop();
                                await _createNewChat();
                              },
                        icon: const Icon(Icons.add_comment),
                        label: Text(I18n.t(ctx, 'aiChat.newChat')),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (listCtx, i) {
                      final session = sessions[i];
                      final isActive = session.id == _activeSessionId;
                      final preview =
                          session.messages.isEmpty
                              ? I18n.t(listCtx, 'aiChat.empty')
                              : session.messages.last.content;
                      return ListTile(
                        selected: isActive,
                        title: Text(
                          session.title.isEmpty
                              ? I18n.t(listCtx, 'aiChat.newChat')
                              : session.title,
                        ),
                        subtitle: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await _selectSession(session);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _loading && isActive
                              ? null
                              : () async {
                                  final deleted = await _deleteSession(session);
                                  if (deleted && mounted) {
                                    Navigator.of(ctx).pop();
                                  }
                                },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (!auth.isProOrExempt) {
      return Scaffold(
        appBar: AppBar(title: Text(I18n.t(context, 'title.aiChat'))),
        body: const ProBlock(feature: 'AI Chat'),
      );
    }

    final active = _activeSessionId != null ? _findSession(_activeSessionId!) : null;
    final messages = active?.messages ?? const <_ChatMessage>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(context, 'title.aiChat')),
        actions: [
          IconButton(
            tooltip: I18n.t(context, 'aiChat.chats'),
            onPressed: _sessions.isEmpty ? null : _openChatList,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: I18n.t(context, 'aiChat.newChat'),
            onPressed: _loading ? null : _createNewChat,
            icon: const Icon(Icons.add_comment),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              I18n.t(context, 'aiChat.disclaimer'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child:
                messages.isEmpty
                    ? Center(child: Text(I18n.t(context, 'aiChat.empty')))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length + (_loading ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (_loading && i == messages.length) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final msg = messages[i];
                          return _ChatBubble(message: msg);
                        },
                      ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: I18n.t(context, 'aiChat.placeholder'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loading ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.role, required this.content});
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};

  static _ChatMessage? fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final content = json['content'];
    if (role is! String || content is! String) return null;
    if (role != 'user' && role != 'assistant') return null;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    return _ChatMessage(role: role, content: trimmed);
  }
}

class _ChatSession {
  _ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  String title;
  final List<_ChatMessage> messages;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  static _ChatSession? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) return null;
    final rawMessages = json['messages'];
    final list = rawMessages is List ? rawMessages : const [];
    final messages =
        list
            .whereType<Map>()
            .map((e) => _ChatMessage.fromJson(e.cast<String, dynamic>()))
            .whereType<_ChatMessage>()
            .toList();
    final createdRaw = json['created_at'];
    final updatedRaw = json['updated_at'];
    final createdAt = createdRaw is String ? DateTime.tryParse(createdRaw) : null;
    final updatedAt = updatedRaw is String ? DateTime.tryParse(updatedRaw) : null;
    return _ChatSession(
      id: id,
      title: title,
      messages: messages,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final cs = Theme.of(context).colorScheme;
    final bg = isUser ? cs.primary : cs.surfaceVariant;
    final fg = isUser ? cs.onPrimary : cs.onSurfaceVariant;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.content, style: TextStyle(color: fg)),
      ),
    );
  }
}
