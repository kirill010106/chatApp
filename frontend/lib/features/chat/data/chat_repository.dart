import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../data/models/conversation.dart';
import '../data/models/message.dart';
import '../../auth/data/models/auth_response.dart';

class ChatRepository {
  final DioClient _client;

  ChatRepository(this._client);

  Future<List<Conversation>> getConversations() async {
    final response = await _client.get(ApiConstants.conversations);
    final list = response.data as List<dynamic>;
    return list.map((e) => Conversation.fromJson(e)).toList();
  }

  Future<Conversation> createConversation(String otherUserId) async {
    final response = await _client.post(
      ApiConstants.conversations,
      data: {'other_user_id': otherUserId},
    );
    return Conversation.fromJson(response.data);
  }

  Future<List<Message>> getMessages(
    String conversationId, {
    DateTime? before,
    int limit = 30,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (before != null) {
      params['before'] = before.toUtc().toIso8601String();
    }
    final response = await _client.get(
      ApiConstants.conversationMessages(conversationId),
      queryParameters: params,
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => Message.fromJson(e)).toList();
  }

  Future<List<User>> searchUsers(String query) async {
    final response = await _client.get(
      ApiConstants.searchUsers,
      queryParameters: {'q': query},
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => User.fromJson(e)).toList();
  }

  Future<void> markRead(String conversationId) async {
    await _client.post(ApiConstants.markConversationRead(conversationId));
  }
}
