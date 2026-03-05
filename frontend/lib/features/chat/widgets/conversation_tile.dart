import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/avatar_widget.dart';
import '../data/models/conversation.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = conversation.displayName;
    final lastMsg = conversation.lastMessage;
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      leading: AvatarWidget(name: name),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: lastMsg != null
          ? Text(
              lastMsg.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
            )
          : Text(
              'No messages yet',
              style: Theme.of(context).textTheme.bodySmall,
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMsg != null)
            Text(
              _formatTime(lastMsg.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: hasUnread
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
            ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : conversation.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return DateFormat.Hm().format(dateTime);
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(dateTime);
    } else {
      return DateFormat.MMMd().format(dateTime);
    }
  }
}
