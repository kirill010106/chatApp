import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_constants.dart';
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

  bool get _isImage {
    final ct = message.contentType;
    return ct == 'image/jpeg' ||
        ct == 'image/png' ||
        ct == 'image/gif' ||
        ct == 'image/webp' ||
        ct == 'image';
  }

  bool get _isVideo {
    final ct = message.contentType;
    return ct == 'video/mp4' || ct == 'video/webm';
  }

  bool get _isFile {
    return !_isImage && !_isVideo && message.contentType != 'text';
  }

  /// Resolve media URL: if it starts with '/' it's a relative backend path.
  String get _mediaUrl {
    final url = message.content;
    if (url.startsWith('/')) {
      return '${ApiConstants.baseUrl}$url';
    }
    return url;
  }

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
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildContent(context),
              const SizedBox(height: 4),
              _buildTimestamp(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isImage) {
      return _buildImageContent(context);
    }
    if (_isVideo) {
      return _buildFileLink(Icons.videocam_rounded);
    }
    if (_isFile) {
      return _buildFileLink(Icons.insert_drive_file_rounded);
    }
    return Text(
      message.content,
      style: const TextStyle(color: Colors.white, fontSize: 15),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
          child: Image.network(
            _mediaUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: 200,
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 200,
              height: 80,
              child: Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileLink(IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _mediaUrl.split('/').last,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(_mediaUrl),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp() {
    return Row(
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
          if (message.isFailed)
            Icon(
              Icons.error_outline,
              size: 14,
              color: Colors.redAccent,
            )
          else if (message.isPending)
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
    );
  }
}
