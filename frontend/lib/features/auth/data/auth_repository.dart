import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import 'models/auth_response.dart';

class AuthRepository {
  final DioClient _client;

  AuthRepository(this._client);

  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String displayName = '',
  }) async {
    final response = await _client.post(
      ApiConstants.register,
      data: {
        'username': username,
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );
    return AuthResponse.fromJson(response.data);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      ApiConstants.login,
      data: {
        'email': email,
        'password': password,
      },
    );
    return AuthResponse.fromJson(response.data);
  }

  Future<User> getMe() async {
    final response = await _client.get(ApiConstants.me);
    return User.fromJson(response.data);
  }
}
