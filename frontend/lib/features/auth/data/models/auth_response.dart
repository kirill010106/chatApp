class User {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String avatarUrl;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatarUrl = '',
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      avatarUrl: (json['avatar_url'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };
}

class AuthResponse {
  final User user;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'] as Map<String, dynamic>;
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: tokens['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String,
    );
  }
}
