import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/message.dart';
import 'conversations_provider.dart';
import 'ws_provider.dart';

final messagesProvider = AsyncNotifierProvider.family<MessagesNotifier,
    List<Message>, String>(() => MessagesNotifier());

class MessagesNotifier extends FamilyAsyncNotifier<List<Message>, String> {
  StreamSubscription? _wsSub;
  bool _hasMore = true;
  bool _loadingMore = false;
  static const _uuid = Uuid();

  String get _conversationId => arg;

  @override
  Future<List<Message>> build(String conversationId) async {
    _hasMore = true;

    // Listen to WebSocket for new messages in this conversation
    final wsService = ref.read(wsServiceProvider);
    _wsSub?.cancel();
    _wsSub = wsService.messageStream
        .where((msg) => msg.conversationId == conversationId)
        .listen(_onNewMessage);
    ref.onDispose(() => _wsSub?.cancel());

    final repo = ref.read(chatRepositoryProvider);
    final msgs = await repo.getMessages(conversationId);
    if (msgs.length < 30) _hasMore = false;
    return msgs;
  }

  void _onNewMessage(Message msg) {
    final current = state.value ?? [];
    // Deduplicate by clientMsgId (optimistic update)
    if (msg.clientMsgId != null && msg.clientMsgId!.isNotEmpty) {
      final idx = current.indexWhere((m) => m.clientMsgId == msg.clientMsgId);
      if (idx >= 0) {
        // Replace pending message with confirmed one
        final newList = [...current];
        newList[idx] = msg;
        state = AsyncData(newList);
        return;
      }
    }
    // Check if has the same id already
    if (current.any((m) => m.id == msg.id)) return;
    // New message — add to beginning (newest first)
    state = AsyncData([msg, ...current]);
  }

  void sendMessage(String content) {
    final authState = ref.read(authStateProvider);
    final currentUser = authState.value;
    if (currentUser == null) return;

    final clientMsgId = _uuid.v4();

    // Optimistic update
    final pending = Message(
      id: clientMsgId,
      conversationId: _conversationId,
      senderId: currentUser.id,
      content: content,
      createdAt: DateTime.now(),
      clientMsgId: clientMsgId,
      isPending: true,
    );

    final current = state.value ?? [];
    state = AsyncData([pending, ...current]);

    // Send via WebSocket
    final wsService = ref.read(wsServiceProvider);
    wsService.sendMessage(
      conversationId: _conversationId,
      content: content,
      clientMsgId: clientMsgId,
    );
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    final current = state.value ?? [];
    if (current.isEmpty) return;

    _loadingMore = true;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final oldest = current.last;
      final older = await repo.getMessages(
        _conversationId,
        before: oldest.createdAt,
      );
      if (older.length < 30) _hasMore = false;
      state = AsyncData([...current, ...older]);
    } finally {
      _loadingMore = false;
    }
  }

  bool get hasMore => _hasMore;
}
