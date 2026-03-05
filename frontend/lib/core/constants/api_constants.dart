class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080/ws',
  );

  // Auth
  static const String register = '/api/v1/auth/register';
  static const String login = '/api/v1/auth/login';
  static const String refresh = '/api/v1/auth/refresh';

  // Users
  static const String me = '/api/v1/users/me';
  static const String searchUsers = '/api/v1/users/search';

  // Conversations
  static const String conversations = '/api/v1/conversations';

  static String conversationMessages(String id) =>
      '/api/v1/conversations/$id/messages';

  static String markConversationRead(String id) =>
      '/api/v1/conversations/$id/read';

  // Media
  static const String mediaUpload = '/api/v1/media/upload';
}
