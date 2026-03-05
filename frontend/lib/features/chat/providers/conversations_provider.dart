import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/chat_repository.dart';
import '../data/models/conversation.dart';
import '../data/models/message.dart';
import '../data/ws_service.dart';
import 'ws_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.read(dioClientProvider));
});

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
        () => ConversationsNotifier());

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  StreamSubscription<Message>? _wsSub;
  StreamSubscription<ReadReceiptEvent>? _readSub;

  @override
  Future<List<Conversation>> build() async {
    final authState = ref.watch(authStateProvider);
    if (authState.value == null) return [];

    // Listen to WebSocket for real-time updates
    final wsService = ref.read(wsServiceProvider);
    _wsSub?.cancel();
    _wsSub = wsService.messageStream.listen(_onWsMessage);
    _readSub?.cancel();
    _readSub = wsService.readReceiptStream.listen(_onReadReceipt);
    ref.onDispose(() {
      _wsSub?.cancel();
      _readSub?.cancel();
    });

    final repo = ref.read(chatRepositoryProvider);
    return repo.getConversations();
  }

  void _onWsMessage(Message msg) {
    final current = state.value ?? [];
    final currentUser = ref.read(authStateProvider).value;

    // Find conversation and move to top with updated last message
    final idx = current.indexWhere((c) => c.id == msg.conversationId);
    if (idx >= 0) {
      final conv = current[idx];
      // Increment unread count only for messages from others
      final addUnread = (currentUser != null && msg.senderId != currentUser.id) ? 1 : 0;
      final updated = conv.copyWith(
        lastMessage: LastMessage(
          id: msg.id,
          content: msg.content,
          senderId: msg.senderId,
          createdAt: msg.createdAt,
        ),
        unreadCount: conv.unreadCount + addUnread,
      );
      final newList = [updated, ...current.where((c) => c.id != conv.id)];
      state = AsyncData(newList);
    } else {
      // Unknown conversation — refresh the list
      ref.invalidateSelf();
    }
  }

  void _onReadReceipt(ReadReceiptEvent event) {
    final current = state.value ?? [];
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    // Only care about our own read receipts (to zero out badge)
    if (event.userId != currentUser.id) return;

    final idx = current.indexWhere((c) => c.id == event.conversationId);
    if (idx >= 0) {
      final conv = current[idx];
      if (conv.unreadCount > 0) {
        final newList = [...current];
        newList[idx] = conv.copyWith(unreadCount: 0);
        state = AsyncData(newList);
      }
    }
  }

  /// Mark a conversation as read (zeroes unread badge locally).
  void markAsRead(String conversationId) {
    final current = state.value ?? [];
    final idx = current.indexWhere((c) => c.id == conversationId);
    if (idx >= 0 && current[idx].unreadCount > 0) {
      final newList = [...current];
      newList[idx] = current[idx].copyWith(unreadCount: 0);
      state = AsyncData(newList);
    }
  }

  Future<Conversation> createConversation(String otherUserId) async {
    final repo = ref.read(chatRepositoryProvider);
    final conv = await repo.createConversation(otherUserId);
    // Refresh conversations list
    ref.invalidateSelf();
    return conv;
  }
}
