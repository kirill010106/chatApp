import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/message.dart';
import '../data/web_file_picker.dart';
import 'conversations_provider.dart';
import 'media_provider.dart';
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

  /// Upload file to S3 then send the URL as a message via WS.
  Future<void> sendMediaMessage(WebFilePickResult file) async {
    final authState = ref.read(authStateProvider);
    final currentUser = authState.value;
    if (currentUser == null) return;

    final clientMsgId = _uuid.v4();
    final fileName = file.name;

    // Optimistic update — show pending placeholder
    final pending = Message(
      id: clientMsgId,
      conversationId: _conversationId,
      senderId: currentUser.id,
      content: 'Uploading $fileName…',
      contentType: 'text',
      createdAt: DateTime.now(),
      clientMsgId: clientMsgId,
      isPending: true,
    );

    final current = state.value ?? [];
    state = AsyncData([pending, ...current]);

    try {
      final mediaService = ref.read(mediaServiceProvider);
      final result = await mediaService.uploadWebFile(file);

      // Replace the pending placeholder content with the uploaded URL
      final updated = state.value ?? [];
      final idx = updated.indexWhere((m) => m.clientMsgId == clientMsgId);
      if (idx >= 0) {
        final newList = [...updated];
        newList[idx] = Message(
          id: clientMsgId,
          conversationId: _conversationId,
          senderId: currentUser.id,
          content: result.url,
          contentType: result.contentType,
          createdAt: DateTime.now(),
          clientMsgId: clientMsgId,
          isPending: true,
        );
        state = AsyncData(newList);
      }

      // Send the URL via WebSocket
      final wsService = ref.read(wsServiceProvider);
      wsService.sendMessage(
        conversationId: _conversationId,
        content: result.url,
        clientMsgId: clientMsgId,
        contentType: result.contentType,
      );
    } catch (e) {
      // Remove pending message on failure
      final updated = state.value ?? [];
      state = AsyncData(updated.where((m) => m.clientMsgId != clientMsgId).toList());
      rethrow;
    }
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
