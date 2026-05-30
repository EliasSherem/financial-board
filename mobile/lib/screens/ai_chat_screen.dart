import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../ui/finsight_ui.dart';
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

  String _legacyHistoryKey(int? userId) =>
      'ai_chat_history_${userId ?? 'anon'}';
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
    final active =
        _activeSessionId != null ? _findSession(_activeSessionId!) : null;
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
                content:
                    reply.isEmpty ? I18n.t(context, 'aiChat.empty') : reply,
              ),
            );
            target.updatedAt = DateTime.now();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${I18n.t(context, 'label.failed')}: $e')),
        );
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
              style: TextButton.styleFrom(foregroundColor: FSColors.danger),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sessions = List<_ChatSession>.from(_sessions)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return FSBottomSheetShell(
          title: I18n.t(ctx, 'aiChat.chats'),
          scrollable: false,
          maxHeightFactor: 0.72,
          footer: FSButton(
            label: I18n.t(ctx, 'aiChat.newChat'),
            icon: Icons.add_comment_outlined,
            fullWidth: true,
            onPressed:
                _loading
                    ? null
                    : () async {
                      Navigator.of(ctx).pop();
                      await _createNewChat();
                    },
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sessions.length,
            itemBuilder: (listCtx, i) {
              final session = sessions[i];
              final isActive = session.id == _activeSessionId;
              final preview =
                  session.messages.isEmpty
                      ? I18n.t(listCtx, 'aiChat.empty')
                      : session.messages.last.content;
              return _ChatSessionTile(
                title:
                    session.title.isEmpty
                        ? I18n.t(listCtx, 'aiChat.newChat')
                        : session.title,
                preview: preview,
                isActive: isActive,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _selectSession(session);
                },
                onDelete:
                    _loading && isActive
                        ? null
                        : () async {
                          final deleted = await _deleteSession(session);
                          if (deleted && mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
              );
            },
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
        backgroundColor: FSColors.background(context),
        appBar: AppBar(
          title: Text(I18n.t(context, 'title.aiChat')),
          backgroundColor: FSColors.background(context),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0.5,
        ),
        body: const ProBlock(feature: 'AI Chat'),
      );
    }

    final active =
        _activeSessionId != null ? _findSession(_activeSessionId!) : null;
    final messages = active?.messages ?? const <_ChatMessage>[];

    return Scaffold(
      backgroundColor: FSColors.background(context),
      appBar: AppBar(
        title: Text(I18n.t(context, 'title.aiChat')),
        backgroundColor: FSColors.background(context),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
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
            padding: const EdgeInsets.fromLTRB(
              FSSpacing.lg,
              FSSpacing.lg,
              FSSpacing.lg,
              FSSpacing.md,
            ),
            child: FSCard(
              variant: FSCardVariant.subtle,
              child: Row(
                children: [
                  const _AiHeaderIcon(),
                  const SizedBox(width: FSSpacing.md),
                  Expanded(
                    child: Text(
                      I18n.t(context, 'aiChat.disclaimer'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FSColors.mutedText(context),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: FSSpacing.md),
                  FSButton(
                    label: I18n.t(context, 'aiChat.newChat'),
                    icon: Icons.add_comment_outlined,
                    size: FSButtonSize.sm,
                    variant: FSButtonVariant.outline,
                    onPressed: _loading ? null : _createNewChat,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child:
                messages.isEmpty
                    ? ListView(
                      padding: const EdgeInsets.fromLTRB(
                        FSSpacing.lg,
                        FSSpacing.md,
                        FSSpacing.lg,
                        FSSpacing.xl,
                      ),
                      children: [
                        FSCard(
                          variant: FSCardVariant.elevated,
                          child: FSEmptyState(
                            icon: Icons.auto_awesome_outlined,
                            title: I18n.t(context, 'aiChat.empty'),
                          ),
                        ),
                        if (_loading) ...[
                          const SizedBox(height: FSSpacing.md),
                          const _ThinkingBubble(),
                        ],
                      ],
                    )
                    : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(
                        FSSpacing.lg,
                        FSSpacing.md,
                        FSSpacing.lg,
                        FSSpacing.xl,
                      ),
                      itemCount: messages.length + (_loading ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (_loading && i == messages.length) {
                          return const _ThinkingBubble();
                        }
                        final msg = messages[i];
                        return _ChatBubble(message: msg);
                      },
                    ),
          ),
          Divider(height: 1, color: FSColors.border(context)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FSSpacing.lg,
                FSSpacing.sm,
                FSSpacing.lg,
                FSSpacing.sm,
              ),
              child: FSCard(
                variant: FSCardVariant.elevated,
                padding: const EdgeInsets.symmetric(
                  horizontal: FSSpacing.md,
                  vertical: FSSpacing.sm,
                ),
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
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: FSSpacing.sm,
                            vertical: FSSpacing.md,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: FSSpacing.sm),
                    _SendButton(onPressed: _loading ? null : _send),
                  ],
                ),
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
    final createdAt =
        createdRaw is String ? DateTime.tryParse(createdRaw) : null;
    final updatedAt =
        updatedRaw is String ? DateTime.tryParse(updatedRaw) : null;
    return _ChatSession(
      id: id,
      title: title,
      messages: messages,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class _AiHeaderIcon extends StatelessWidget {
  const _AiHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FSColors.intentContainer(context, FSIntent.info),
        borderRadius: BorderRadius.circular(FSRadius.md),
        border: Border.all(
          color: FSColors.intentBorder(context, FSIntent.info),
        ),
      ),
      child: const Icon(Icons.auto_awesome_outlined, color: FSColors.info),
    );
  }
}

class _ChatSessionTile extends StatelessWidget {
  const _ChatSessionTile({
    required this.title,
    required this.preview,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final String preview;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FSSpacing.sm),
      child: FSCard(
        onTap: onTap,
        variant: isActive ? FSCardVariant.interactive : FSCardVariant.subtle,
        padding: const EdgeInsets.all(FSSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FSColors.intentContainer(
                  context,
                  isActive ? FSIntent.primary : FSIntent.neutral,
                ),
                borderRadius: BorderRadius.circular(FSRadius.md),
                border: Border.all(
                  color: FSColors.intentBorder(
                    context,
                    isActive ? FSIntent.primary : FSIntent.neutral,
                  ),
                ),
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 19,
                color: isActive ? FSColors.primary : FSColors.neutral,
              ),
            ),
            const SizedBox(width: FSSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: FSSpacing.xs),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FSColors.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FSSpacing.sm),
            IconButton(
              tooltip: I18n.t(context, 'label.delete'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(40),
                foregroundColor: FSColors.danger,
                backgroundColor: FSColors.alpha(FSColors.danger, 0.10),
                side: BorderSide(color: FSColors.alpha(FSColors.danger, 0.18)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FSRadius.md),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FSSpacing.sm),
          child: FSCard(
            variant: FSCardVariant.subtle,
            padding: const EdgeInsets.symmetric(
              horizontal: FSSpacing.md,
              vertical: FSSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FSColors.intentContainer(context, FSIntent.info),
                    borderRadius: BorderRadius.circular(FSRadius.pill),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_outlined,
                    size: 16,
                    color: FSColors.info,
                  ),
                ),
                const SizedBox(width: FSSpacing.md),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: I18n.t(context, 'aiChat.placeholder'),
      onPressed: onPressed,
      icon: const Icon(Icons.send_rounded, size: 19),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor:
            onPressed == null
                ? FSColors.alpha(FSColors.primary, 0.38)
                : FSColors.primary,
        foregroundColor: Colors.white,
        disabledForegroundColor: FSColors.alpha(Colors.white, 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.md),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final maxWidth = MediaQuery.of(context).size.width * 0.82;
    final bubbleColor =
        isUser ? FSColors.primary : FSColors.surfaceElevated(context);
    final textColor =
        isUser ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final borderColor =
        isUser
            ? FSColors.alpha(FSColors.primary, 0.22)
            : FSColors.border(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: FSSpacing.sm),
          padding: const EdgeInsets.all(FSSpacing.md),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(FSRadius.lg),
              topRight: const Radius.circular(FSRadius.lg),
              bottomLeft: Radius.circular(isUser ? FSRadius.lg : FSRadius.sm),
              bottomRight: Radius.circular(isUser ? FSRadius.sm : FSRadius.lg),
            ),
            border: Border.all(color: borderColor),
            boxShadow: isUser ? FSShadows.none : FSShadows.soft(context),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FSColors.intentContainer(context, FSIntent.info),
                    borderRadius: BorderRadius.circular(FSRadius.pill),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_outlined,
                    size: 16,
                    color: FSColors.info,
                  ),
                ),
                const SizedBox(width: FSSpacing.md),
              ],
              Flexible(
                child: Text(
                  message.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.42,
                    fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
