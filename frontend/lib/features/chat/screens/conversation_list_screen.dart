import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/data/models/auth_response.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/push_provider.dart';
import '../widgets/conversation_tile.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    // Initialize push notifications when authenticated
    ref.watch(pushInitProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: conversations.when(
        data: (convs) {
          if (convs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: AppTheme.subtitleColor),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(color: AppTheme.subtitleColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to start chatting',
                    style: TextStyle(
                        color: AppTheme.subtitleColor, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: convs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final conv = convs[index];
              return ConversationTile(
                conversation: conv,
                onTap: () {
                  context.go(
                    '/chat/${conv.id}?name=${Uri.encodeComponent(conv.displayName)}',
                  );
                },
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSearchDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _UserSearchDialog(),
    );
  }
}

class _UserSearchDialog extends ConsumerStatefulWidget {
  const _UserSearchDialog();

  @override
  ConsumerState<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends ConsumerState<_UserSearchDialog> {
  final _searchController = TextEditingController();
  List<User> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final users = await repo.searchUsers(query);
      // Filter out current user
      final me = ref.read(authStateProvider).value;
      setState(() {
        _results = users.where((u) => u.id != me?.id).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startChat(User user) async {
    try {
      final notifier = ref.read(conversationsProvider.notifier);
      final conv = await notifier.createConversation(user.id);
      if (mounted) {
        Navigator.of(context).pop();
        context.go(
          '/chat/${conv.id}?name=${Uri.encodeComponent(user.displayName.isNotEmpty ? user.displayName : user.username)}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Chat'),
      content: SizedBox(
        width: 350,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const LoadingWidget()
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            'Search for users to start chatting',
                            style: TextStyle(color: AppTheme.subtitleColor),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final user = _results[index];
                            return ListTile(
                              leading: AvatarWidget(
                                name: user.displayName.isNotEmpty
                                    ? user.displayName
                                    : user.username,
                                size: 40,
                              ),
                              title: Text(user.displayName.isNotEmpty
                                  ? user.displayName
                                  : user.username),
                              subtitle: Text('@${user.username}'),
                              onTap: () => _startChat(user),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
