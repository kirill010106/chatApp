import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import 'models/message.dart';

/// Represents a read receipt event from WS.
class ReadReceiptEvent {
  final String conversationId;
  final String userId;

  ReadReceiptEvent({required this.conversationId, required this.userId});
}

/// Connection state exposed to the UI.
enum WsConnectionState { connected, connecting, disconnected }

class WsService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  String? _token;
  bool _disposed = false;

  /// Tracks whether we are in the middle of a connect attempt.
  bool _connecting = false;

  /// Consecutive fast-close count (possible auth failures).
  int _fastCloseCount = 0;
  static const _maxFastCloses = 3;

  final _messageController = StreamController<Message>.broadcast();
  Stream<Message> get messageStream => _messageController.stream;

  final _readReceiptController = StreamController<ReadReceiptEvent>.broadcast();
  Stream<ReadReceiptEvent> get readReceiptStream =>
      _readReceiptController.stream;

  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();
  Stream<WsConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  WsConnectionState _currentState = WsConnectionState.disconnected;
  WsConnectionState get currentState => _currentState;

  bool get isConnected => _currentState == WsConnectionState.connected;

  void _setState(WsConnectionState s) {
    if (_currentState == s) return;
    _currentState = s;
    _connectionStateController.add(s);
  }

  /// Called by the provider when the user logs in / has a token.
  void connect(String token) {
    // If we already have a live connection with this token — skip.
    if (_token == token && _channel != null && !_disposed) return;

    // New token (or first call) — reset everything.
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;

    _token = token;
    _disposed = false;
    _retryCount = 0;
    _fastCloseCount = 0;
    _connecting = false;

    _doConnect();
  }

  void _doConnect() {
    if (_disposed || _token == null || _connecting) return;

    _connecting = true;
    _setState(WsConnectionState.connecting);
    final connectTime = DateTime.now();

    final wsBase = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/ws?token=$_token');
    _channel = WebSocketChannel.connect(uri);

    bool receivedData = false;

    _channel!.stream.listen(
      (data) {
        if (!receivedData) {
          receivedData = true;
          _retryCount = 0;
          _fastCloseCount = 0;
          _setState(WsConnectionState.connected);
        }
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
    _setState(WsConnectionState.disconnected);
    if (_disposed) return;

    // If the connection closed very quickly and we never received data,
    // this is likely a 401 / auth rejection.
    final lifetime = DateTime.now().difference(connectTime);
    if (!receivedData && lifetime.inSeconds < 5) {
      _fastCloseCount++;
      if (_fastCloseCount >= _maxFastCloses) {
        debugPrint(
            'WS: ${'auth failure detected after $_fastCloseCount fast closes'} — '
            'pausing reconnection for 30s');
        // Don't block forever — schedule a retry after 30s with a fresh token
        _reconnectTimer = Timer(const Duration(seconds: 30), () async {
          _fastCloseCount = 0;
          final freshToken = await SecureStorage.getAccessToken();
          if (freshToken != null && !_disposed) {
            _token = freshToken;
            _doConnect();
          }
        });
        return;
      }
    }

    // Exponential backoff with a cap of 30 seconds
    final delaySecs = min(pow(2, _retryCount).toInt(), 30);
    final delay = Duration(seconds: delaySecs);
    debugPrint('WS: reconnecting in ${delay.inSeconds}s (attempt ${_retryCount + 1})');

    _reconnectTimer = Timer(delay, () async {
      _retryCount++;
      // Re-read token — Dio interceptor may have refreshed it.
      final freshToken = await SecureStorage.getAccessToken();
      if (freshToken != null && !_disposed) {
        _token = freshToken;
        _doConnect();
      }
    });
  }

  /// Returns true if the message was buffered for sending.
  bool sendMessage({
    required String conversationId,
    required String content,
    required String clientMsgId,
    String contentType = 'text',
  }) {
    if (_channel == null) return false;
    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'conversation_id': conversationId,
      'content': content,
      'content_type': contentType,
      'client_msg_id': clientMsgId,
    }));
    return true;
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
    _setState(WsConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _readReceiptController.close();
    _connectionStateController.close();
  }
}
  }
}
