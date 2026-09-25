import '../momentum/store.dart';
import '../momentum/widgets.dart';
import '../services/client_context.dart';
import '../services/analytics_service.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../widgets/pro_widgets.dart';
import '../liquid_glass/liquid_glass.dart';

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
  String? _requestId;
  String? _requestSession;
  List<Map<String, String>>? _requestMessages;
  int? _sessionUser;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _sessionUser = context.read<AuthStore>().userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AnalyticsService.instance.screen('ai');
    });
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
    final userId = _sessionUser;
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
    final userId = _sessionUser;
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
    if (_loading || _requestId != null) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final session = _ensureActiveSession();
    setState(() {
      session.messages.add(_ChatMessage(role: 'user', content: text));
      if (session.messages.length == 1) session.title = _truncateTitle(text);
      session.updatedAt = DateTime.now();
      _requestId = clientEventId();
      _requestSession = session.id;
      final payload = session.messages.map((m) => m.toJson()).toList();
      _requestMessages =
          payload.length > 20 ? payload.sublist(payload.length - 20) : payload;
    });
    _inputCtrl.clear();
    await _saveSessions();
    if (mounted) await _performRequest();
  }

  Future<void> _performRequest() async {
    if (_loading || _requestId == null || _requestMessages == null) return;
    final auth = context.read<AuthStore>();
    if (auth.userId != _sessionUser || !auth.isAuthenticated) return;
    final token = auth.token;
    final sessionId = _requestSession;
    setState(() => _loading = true);
    _scrollToBottom();
    try {
      final reply = await DataService(
        ApiClient()..setToken(token),
      ).aiChat(messages: _requestMessages!, requestId: _requestId);
      if (!mounted || auth.token != token) return;
      setState(() {
        final target = _findSession(sessionId ?? '');
        if (target != null) {
          target.messages.add(
            _ChatMessage(
              role: 'assistant',
              content: reply.isEmpty ? I18n.t(context, 'aiChat.empty') : reply,
            ),
          );
          target.updatedAt = DateTime.now();
        }
        _requestId = null;
        _requestMessages = null;
        _requestSession = null;
      });
      AnalyticsService.instance.event('feature_used', feature: 'ai');
      await context.read<MomentumStore>().refresh();
    } on ApiException catch (e) {
      if (!mounted || auth.token != token) return;
      final terminal =
          e.statusCode == 403 ||
          const {
            'AI_REQUEST_FINISHED',
            'AI_RETRY_CACHE_EXPIRED',
            'REQUEST_ID_UNAVAILABLE',
          }.contains(e.code);
      if (terminal) {
        setState(() {
          _requestId = null;
          _requestMessages = null;
          _requestSession = null;
        });
        await context.read<MomentumStore>().refresh();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            momentumText(
              context,
              terminal
                  ? 'This request is no longer available. Check your access and question balance before starting a new one.'
                  : 'The response is not confirmed yet. Retry the same request shortly.',
              terminal
                  ? 'Esta solicitud ya no está disponible. Comprueba tu acceso y saldo de preguntas antes de iniciar otra.'
                  : 'La respuesta todavía no está confirmada. Reintenta la misma solicitud en unos momentos.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted && auth.token == token) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              momentumText(
                context,
                'No response confirmed. Retry the same question without using a second credit.',
                'No se confirmó respuesta. Reintenta la misma pregunta sin consumir un segundo crédito.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted && auth.token == token) {
        setState(() => _loading = false);
        await _saveSessions();
        if (_activeSessionId == sessionId) _scrollToBottom();
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
          backgroundColor: LGColors.surfaceSolid(context),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LGRadius.xl),
            side: BorderSide(
              color: LGColors.textSecondary(context).withValues(alpha: 0.14),
            ),
          ),
          title: Text(I18n.t(ctx, 'aiChat.deleteTitle')),
          content: Text(I18n.t(ctx, 'aiChat.deleteBody')),
          actions: [
            LGButton(
              label: I18n.t(ctx, 'label.cancel'),
              size: LGButtonSize.sm,
              variant: LGButtonVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            _SoftDangerButton(
              label: I18n.t(ctx, 'label.delete'),
              onPressed: () => Navigator.of(ctx).pop(true),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sessions = List<_ChatSession>.from(_sessions)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return LGBottomSheetShell(
          title: I18n.t(ctx, 'aiChat.chats'),
          scrollable: false,
          maxHeightFactor: 0.72,
          footer: LGButton(
            label: I18n.t(ctx, 'aiChat.newChat'),
            icon: Icons.add_comment,
            variant: LGButtonVariant.outline,
            onPressed:
                _loading
                    ? null
                    : () async {
                      Navigator.of(ctx).pop();
                      await _createNewChat();
                    },
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.46,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: sessions.length,
                    itemBuilder: (listCtx, i) {
                      final session = sessions[i];
                      final isActive = session.id == _activeSessionId;
                      final preview =
                          session.messages.isEmpty
                              ? I18n.t(listCtx, 'aiChat.empty')
                              : session.messages.last.content;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: LGSpacing.sm),
                        child: LGSolidCard(
                          tinted: isActive,
                          padding: const EdgeInsets.all(LGSpacing.md),
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await _selectSession(session);
                          },
                          child: Row(
                            children: [
                              _ChatIconBox(
                                icon: Icons.chat_bubble_outline,
                                color:
                                    isActive
                                        ? Theme.of(context).colorScheme.primary
                                        : LGColors.textSecondary(context),
                                size: 42,
                              ),
                              const SizedBox(width: LGSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      session.title.isEmpty
                                          ? I18n.t(listCtx, 'aiChat.newChat')
                                          : session.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.copyWith(
                                        color: LGColors.textPrimary(context),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: LGSpacing.xs),
                                    Text(
                                      preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: LGColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: LGSpacing.sm),
                              _SoftIconButton(
                                tooltip: I18n.t(context, 'label.delete'),
                                icon: Icons.delete_outline,
                                color: LGColors.danger,
                                onPressed:
                                    _loading && isActive
                                        ? null
                                        : () async {
                                          final deleted = await _deleteSession(
                                            session,
                                          );
                                          if (deleted && mounted) {
                                            Navigator.of(ctx).pop();
                                          }
                                        },
                              ),
                            ],
                          ),
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

  Widget _pageHeader() {
    return LGPageHeader(
      title: I18n.t(context, 'title.aiChat'),
      subtitle: I18n.t(context, 'aiChat.disclaimer'),
      leading: _ChatIconBox(
        icon: Icons.auto_awesome_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 52,
      ),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SoftIconButton(
            tooltip: I18n.t(context, 'aiChat.chats'),
            icon: Icons.chat_bubble_outline,
            color: Theme.of(context).colorScheme.primary,
            onPressed: _sessions.isEmpty ? null : _openChatList,
          ),
          const SizedBox(width: LGSpacing.sm),
          _SoftIconButton(
            tooltip: I18n.t(context, 'aiChat.newChat'),
            icon: Icons.add_comment,
            color: Theme.of(context).colorScheme.primary,
            onPressed: _loading || _requestId != null ? null : _createNewChat,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final momentum = context.watch<MomentumStore>().state;
    if (!auth.isProOrExempt &&
        !(momentum?.canUseCredits ?? false) &&
        _requestId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
          children: [
            _pageHeader(),
            const SizedBox(height: LGSpacing.md),
            const ProBlock(feature: 'AI Chat'),
          ],
        ),
      );
    }

    final active =
        _activeSessionId != null ? _findSession(_activeSessionId!) : null;
    final messages = active?.messages ?? const <_ChatMessage>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          if (!auth.isProOrExempt)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${momentum?.creditBalance ?? 0} ${momentumText(context, 'AI questions available', 'preguntas IA disponibles')}',
              ),
            ),
          if (_requestId != null && !_loading)
            TextButton.icon(
              onPressed: _performRequest,
              icon: const Icon(Icons.refresh),
              label: Text(
                momentumText(
                  context,
                  'Retry the same question',
                  'Reintentar la misma pregunta',
                ),
              ),
            ),
          Expanded(
            child:
                messages.isEmpty
                    ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _pageHeader(),
                        const SizedBox(height: LGSpacing.lg),
                        LGEmptyState(
                          icon: Icons.auto_awesome_rounded,
                          title: I18n.t(context, 'aiChat.empty'),
                          message: I18n.t(context, 'aiChat.disclaimer'),
                        ),
                      ],
                    )
                    : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: messages.length + (_loading ? 1 : 0) + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return Column(
                            children: [
                              _pageHeader(),
                              const SizedBox(height: LGSpacing.md),
                            ],
                          );
                        }
                        final messageIndex = i - 1;
                        if (_loading && messageIndex == messages.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: LGSpacing.sm),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: LGGlassCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: LGSpacing.md,
                                  vertical: LGSpacing.sm,
                                ),
                                child: LGLoadingState(
                                  label: I18n.t(context, 'title.aiChat'),
                                  compact: true,
                                ),
                              ),
                            ),
                          );
                        }
                        final msg = messages[messageIndex];
                        return _ChatBubble(message: msg);
                      },
                    ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: LGGlassSurface(
                blur: LGBlur.subtle,
                intensity:
                    LGColors.isDark(context)
                        ? LGGlassIntensity.medium
                        : LGGlassIntensity.strong,
                borderRadius: BorderRadius.circular(LGRadius.xxl),
                padding: const EdgeInsets.fromLTRB(
                  LGSpacing.md,
                  LGSpacing.sm,
                  LGSpacing.sm,
                  LGSpacing.sm,
                ),
                shadows: LGShadows.glass(context),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 4,
                        enabled: _requestId == null,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: I18n.t(context, 'aiChat.placeholder'),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          hintStyle: TextStyle(
                            color: LGColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: LGSpacing.sm),
                    _SendButton(loading: _loading, onPressed: _send),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final primary = Theme.of(context).colorScheme.primary;
    final color = isUser ? primary : LGColors.textSecondary(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: LGSpacing.xs),
          child: LGSolidCard(
            tinted: !isUser,
            padding: const EdgeInsets.all(LGSpacing.md),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(LGRadius.xl),
              topRight: const Radius.circular(LGRadius.xl),
              bottomLeft: Radius.circular(isUser ? LGRadius.xl : LGRadius.sm),
              bottomRight: Radius.circular(isUser ? LGRadius.sm : LGRadius.xl),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser) ...[
                  _ChatIconBox(
                    icon: Icons.auto_awesome_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 34,
                  ),
                  const SizedBox(width: LGSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LGColors.textPrimary(context),
                      height: 1.38,
                    ),
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: LGSpacing.sm),
                  _ChatIconBox(
                    icon: Icons.person_outline,
                    color: color,
                    size: 34,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatIconBox extends StatelessWidget {
  const _ChatIconBox({required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: LGColors.isDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(
          size >= 48 ? LGRadius.lg : LGRadius.md,
        ),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: color, size: size >= 48 ? 25 : 18),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LGRadius.md),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: LGColors.isDark(context) ? 0.18 : 0.09,
                ),
                borderRadius: BorderRadius.circular(LGRadius.md),
                border: Border.all(color: color.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.lg),
        onTap: loading ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                loading
                    ? LGColors.textSecondary(context).withValues(alpha: 0.18)
                    : LGColors.primaryBlue,
            borderRadius: BorderRadius.circular(LGRadius.lg),
            boxShadow:
                loading
                    ? LGShadows.none
                    : [
                      BoxShadow(
                        color: LGColors.primaryBlue.withValues(alpha: 0.24),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
          ),
          child:
              loading
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.send_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _SoftDangerButton extends StatelessWidget {
  const _SoftDangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: LGSpacing.md),
        foregroundColor: LGColors.danger,
        backgroundColor: LGColors.danger.withValues(
          alpha: LGColors.isDark(context) ? 0.18 : 0.08,
        ),
        side: BorderSide(color: LGColors.danger.withValues(alpha: 0.28)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LGRadius.pill),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}
