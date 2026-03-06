import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/web_file_picker.dart';

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
  DateTime? _otherLastReadAt;
  bool _isUploading = false;
  StreamSubscription<ReadReceiptEvent>? _readSub;
  StreamSubscription<WsConnectionState>? _connSub;
  WsConnectionState _connState = WsConnectionState.connected;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _listenReadReceipts();
    _listenConnectionState();
    // Delay provider modification until after widget tree is built
    Future.microtask(() {
      _markAsRead();
      _fetchReadStatus();
    });
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
        // Other user just read — update timestamp to now
        if (mounted) {
          setState(() => _otherLastReadAt = DateTime.now());
        }
      }
    });
  }

  Future<void> _fetchReadStatus() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final ts = await repo.getReadStatus(widget.conversationId);
      if (mounted && ts != null) {
        setState(() => _otherLastReadAt = ts);
      }
    } catch (_) {
      // Non-critical, ignore errors
    }
  }

  void _listenConnectionState() {
    final wsService = ref.read(wsServiceProvider);
    _connState = wsService.currentState;
    _connSub = wsService.connectionStateStream.listen((s) {
      if (mounted) setState(() => _connState = s);
    });
  }

  @override
  void dispose() {
    _readSub?.cancel();
    _connSub?.cancel();
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
    ref
        .read(messagesProvider(widget.conversationId).notifier)
        .sendMessage(text);
  }

  Future<void> _onSendFile(WebFilePickResult file) async {
    setState(() {
      _isUploading = true;
    });
    try {
      await ref
          .read(messagesProvider(widget.conversationId).notifier)
          .sendMediaMessage(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
          if (_connState != WsConnectionState.connected)
            MaterialBanner(
              content: Text(
                _connState == WsConnectionState.connecting
                    ? 'Reconnecting…'
                    : 'No connection',
              ),
              leading: _connState == WsConnectionState.connecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_off, color: Colors.red),
              backgroundColor: Colors.orange.shade100,
              actions: const [SizedBox.shrink()],
            ),
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
                    // Message is read if it was sent before the other user's last read
                    final isRead = isMine &&
                        _otherLastReadAt != null &&
                        !msg.isPending &&
                        !msg.isFailed &&
                        !msg.createdAt.isAfter(_otherLastReadAt!);
                    final bubble = MessageBubble(
                      message: msg,
                      isMine: isMine,
                      isRead: isRead,
                    );
                    if (msg.isFailed && msg.clientMsgId != null) {
                      return GestureDetector(
                        onTap: () => ref
                            .read(messagesProvider(widget.conversationId)
                                .notifier)
                            .retryMessage(msg.clientMsgId!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            bubble,
                            const Padding(
                              padding: EdgeInsets.only(right: 12, bottom: 4),
                              child: Text(
                                'Tap to retry',
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return bubble;
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          MessageInput(
            onSend: _onSend,
            onSendFile: _onSendFile,
            isUploading: _isUploading,
          ),
        ],
      ),
    );
  }
}
