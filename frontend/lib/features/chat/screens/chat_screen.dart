import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/ws_service.dart';
import '../providers/conversations_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/ws_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUsername;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUsername,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  bool _otherHasRead = false;
  StreamSubscription<ReadReceiptEvent>? _readSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _listenReadReceipts();
    // Delay provider modification until after widget tree is built
    Future.microtask(() => _markAsRead());
  }

  void _markAsRead() {
    // Send via REST + WS
    final repo = ref.read(chatRepositoryProvider);
    repo.markRead(widget.conversationId);
    final wsService = ref.read(wsServiceProvider);
    wsService.sendReadReceipt(conversationId: widget.conversationId);
    // Zero badge locally
    ref.read(conversationsProvider.notifier).markAsRead(widget.conversationId);
  }

  void _listenReadReceipts() {
    final wsService = ref.read(wsServiceProvider);
    final currentUser = ref.read(authStateProvider).value;
    _readSub = wsService.readReceiptStream.listen((event) {
      if (event.conversationId == widget.conversationId &&
          currentUser != null &&
          event.userId != currentUser.id) {
        if (mounted) {
          setState(() => _otherHasRead = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _readSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more messages when scrolled near the top (list is reversed)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(messagesProvider(widget.conversationId).notifier).loadMore();
    }
  }

  void _onSend(String text) {
    // After sending, the other user hasn't read yet
    setState(() => _otherHasRead = false);
    ref
        .read(messagesProvider(widget.conversationId).notifier)
        .sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final currentUser = ref.watch(authStateProvider).value;

    // Mark as read when new messages arrive while screen is open
    ref.listen(messagesProvider(widget.conversationId), (prev, next) {
      final prevLen = prev?.value?.length ?? 0;
      final nextLen = next.value?.length ?? 0;
      if (nextLen > prevLen) {
        // New message arrived while we're in the chat — mark read
        final repo = ref.read(chatRepositoryProvider);
        repo.markRead(widget.conversationId);
        final wsService = ref.read(wsServiceProvider);
        wsService.sendReadReceipt(conversationId: widget.conversationId);
        ref
            .read(conversationsProvider.notifier)
            .markAsRead(widget.conversationId);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/conversations'),
        ),
        title: Text(widget.otherUsername),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              data: (msgs) {
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hello!'),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final msg = msgs[index];
                    final isMine = msg.senderId == currentUser?.id;
                    // In a 1-to-1 chat, if the other user has read,
                    // all my sent messages are read
                    final isRead = isMine && _otherHasRead;
                    return MessageBubble(
                      message: msg,
                      isMine: isMine,
                      isRead: isRead,
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          MessageInput(onSend: _onSend),
        ],
      ),
    );
  }
}
