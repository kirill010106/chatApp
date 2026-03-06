import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/storage/secure_storage.dart';
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

  /// Tracks whether we are in the middle of a connect attempt.
  bool _connecting = false;

  /// Set to true when a 401 / auth-failure is detected.
  /// Blocks ALL automatic reconnection until [connect] is called with
  /// a **different** token.
  bool _authFailed = false;

  final _messageController = StreamController<Message>.broadcast();
  Stream<Message> get messageStream => _messageController.stream;

  final _readReceiptController = StreamController<ReadReceiptEvent>.broadcast();
  Stream<ReadReceiptEvent> get readReceiptStream =>
      _readReceiptController.stream;

  /// Called by the provider when the user logs in / has a token.
  void connect(String token) {
    // If we already have a live connection with this token — skip.
    if (_token == token && _channel != null && !_disposed) return;

    // If auth previously failed and caller passes the SAME token — skip.
    if (_authFailed && _token == token) return;

    // New token (or first call) — reset everything.
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;

    _token = token;
    _disposed = false;
    _retryCount = 0;
    _authFailed = false;
    _connecting = false;

    _doConnect();
  }

  void _doConnect() {
    if (_disposed || _token == null || _connecting || _authFailed) return;

    _connecting = true;
    final connectTime = DateTime.now();

    final wsBase = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/ws?token=$_token');
    _channel = WebSocketChannel.connect(uri);

    bool receivedData = false;

    _channel!.stream.listen(
      (data) {
        receivedData = true;
        _retryCount = 0; // connection is healthy
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'message') {
            _messageController.add(Message.fromJson(json));
          } else if (type == 'read_receipt') {
            _readReceiptController.add(ReadReceiptEvent(
              conversationId: json['conversation_id'] as String,
              userId: json['sender_id'] as String,
            ));
          }
        } catch (_) {}
      },
      onDone: () => _onDisconnect(receivedData, connectTime),
      onError: (_) => _onDisconnect(receivedData, connectTime),
    );

    _connecting = false;
  }

  void _onDisconnect(bool receivedData, DateTime connectTime) {
    _channel = null;
    if (_disposed) return;

    // If the connection closed very quickly and we never received data,
    // this is almost certainly a 401 / auth rejection.
    final lifetime = DateTime.now().difference(connectTime);
    if (!receivedData && lifetime.inSeconds < 5) {
      debugPrint('WS: auth failure detected (closed in ${lifetime.inMilliseconds}ms with no data) — stopping');
      _authFailed = true;
      return;
    }

    // Normal disconnect — try to reconnect with backoff.
    if (_retryCount >= AppConstants.wsMaxReconnectAttempts) {
      debugPrint('WS: max reconnect attempts reached — stopping');
      return;
    }

    final delay =
        AppConstants.wsReconnectBaseDelay * pow(2, _retryCount).toInt();
    debugPrint('WS: reconnecting in ${delay.inSeconds}s (attempt ${_retryCount + 1})');

    _reconnectTimer = Timer(delay, () async {
      _retryCount++;
      // Re-read token — Dio interceptor may have refreshed it.
      final freshToken = await SecureStorage.getAccessToken();
      if (freshToken != null && !_disposed && !_authFailed) {
        _token = freshToken;
        _doConnect();
      }
    });
  }

  void sendMessage({
    required String conversationId,
    required String content,
    required String clientMsgId,
    String contentType = 'text',
  }) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'conversation_id': conversationId,
      'content': content,
      'content_type': contentType,
      'client_msg_id': clientMsgId,
    }));
  }

  void sendReadReceipt({required String conversationId}) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'read_receipt',
      'conversation_id': conversationId,
    }));
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
