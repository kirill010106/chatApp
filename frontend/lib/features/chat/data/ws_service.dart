import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import 'models/message.dart';

/// Represents a read receipt event from WS.
class ReadReceiptEvent {
  final String conversationId;
  final String userId;

  ReadReceiptEvent({required this.conversationId, required this.userId});
}

class WsService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  String? _token;
  bool _disposed = false;

  final _messageController = StreamController<Message>.broadcast();
  Stream<Message> get messageStream => _messageController.stream;

  final _readReceiptController = StreamController<ReadReceiptEvent>.broadcast();
  Stream<ReadReceiptEvent> get readReceiptStream => _readReceiptController.stream;

  void connect(String token) {
    _token = token;
    _disposed = false;
    _doConnect();
  }

  void _doConnect() {
    if (_disposed || _token == null) return;

    final uri = Uri.parse('${ApiConstants.wsUrl}?token=$_token');
    _channel = WebSocketChannel.connect(uri);
    _retryCount = 0;

    _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'message') {
            final msg = Message.fromJson(json);
            _messageController.add(msg);
          } else if (type == 'read_receipt') {
            _readReceiptController.add(ReadReceiptEvent(
              conversationId: json['conversation_id'] as String,
              userId: json['sender_id'] as String,
            ));
          }
        } catch (_) {}
      },
      onDone: _onDisconnect,
      onError: (_) => _onDisconnect(),
    );
  }

  void _onDisconnect() {
    if (_disposed) return;
    if (_retryCount >= AppConstants.wsMaxReconnectAttempts) return;

    final delay = AppConstants.wsReconnectBaseDelay *
        pow(2, _retryCount).toInt();
    _reconnectTimer = Timer(delay, () {
      _retryCount++;
      _doConnect();
    });
  }

  void sendMessage({
    required String conversationId,
    required String content,
    required String clientMsgId,
    String contentType = 'text',
  }) {
    if (_channel == null) return;

    final payload = jsonEncode({
      'type': 'message',
      'conversation_id': conversationId,
      'content': content,
      'content_type': contentType,
      'client_msg_id': clientMsgId,
    });

    _channel!.sink.add(payload);
  }

  void sendReadReceipt({required String conversationId}) {
    if (_channel == null) return;

    final payload = jsonEncode({
      'type': 'read_receipt',
      'conversation_id': conversationId,
    });

    _channel!.sink.add(payload);
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _readReceiptController.close();
  }
}
