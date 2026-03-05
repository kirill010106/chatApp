class Conversation {
  final String id;
  final bool isGroup;
  final String title;
  final DateTime createdAt;
  final ConversationUser? otherUser;
  final LastMessage? lastMessage;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.isGroup,
    this.title = '',
    required this.createdAt,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      isGroup: json['is_group'] as bool,
      title: (json['title'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      otherUser: json['other_user'] != null
          ? ConversationUser.fromJson(json['other_user'])
          : null,
      lastMessage: json['last_message'] != null
          ? LastMessage.fromJson(json['last_message'])
          : null,
      unreadCount: (json['unread_count'] as int?) ?? 0,
    );
  }

  String get displayName {
    if (isGroup && title.isNotEmpty) return title;
    return otherUser?.displayName ?? otherUser?.username ?? 'Unknown';
  }

  Conversation copyWith({
    LastMessage? lastMessage,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      isGroup: isGroup,
      title: title,
      createdAt: createdAt,
      otherUser: otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ConversationUser {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  ConversationUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl = '',
  });

  factory ConversationUser.fromJson(Map<String, dynamic> json) {
    return ConversationUser(
      id: json['id'] as String,
      username: (json['username'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      avatarUrl: (json['avatar_url'] as String?) ?? '',
    );
  }
}

class LastMessage {
  final String id;
  final String content;
  final String senderId;
  final DateTime createdAt;

  LastMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.createdAt,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      id: json['id'] as String,
      content: (json['content'] as String?) ?? '',
      senderId: (json['sender_id'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
