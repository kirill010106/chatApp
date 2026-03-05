class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String contentType;
  final DateTime createdAt;
  final String? clientMsgId;
  final bool isPending;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.contentType = 'text',
    required this.createdAt,
    this.clientMsgId,
    this.isPending = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      contentType: (json['content_type'] as String?) ?? 'text',
      createdAt: DateTime.parse(json['created_at'] as String),
      clientMsgId: json['client_msg_id'] as String?,
    );
  }

  /// Create a copy with updated fields (for optimistic updates).
  Message copyWith({
    String? id,
    bool? isPending,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      contentType: contentType,
      createdAt: createdAt ?? this.createdAt,
      clientMsgId: clientMsgId,
      isPending: isPending ?? this.isPending,
    );
  }
}
