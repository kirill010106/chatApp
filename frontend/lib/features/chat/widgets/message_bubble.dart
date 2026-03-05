import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final bool isRead;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMine ? 64 : 8,
          right: isMine ? 8 : 64,
          top: 2,
          bottom: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine
              ? AppTheme.sentBubbleColor
              : AppTheme.receivedBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.Hm().format(message.createdAt.toLocal()),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  if (message.isPending)
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    )
                  else
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: isRead
                          ? Colors.lightBlueAccent
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
