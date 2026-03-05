import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_response.dart';

// Singleton DioClient provider
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

// Auth repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioClientProvider));
});

// Auth state: holds the current user or null
final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    // Try to restore session from stored tokens
    final accessToken = await SecureStorage.getAccessToken();
    if (accessToken == null) return null;

    final client = ref.read(dioClientProvider);
    client.setAccessToken(accessToken);

    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.getMe();
      return user;
    } catch (_) {
      // Token expired or invalid
      client.clearAccessToken();
      await SecureStorage.clearAll();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.login(email: email, password: password);
      await _saveTokens(response);
      return response.user;
    });
  }

  Future<void> register(
      String username, String email, String password, String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.register(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
      );
      await _saveTokens(response);
      return response.user;
    });
  }

  Future<void> logout() async {
    final client = ref.read(dioClientProvider);
    client.clearAccessToken();
    await SecureStorage.clearAll();
    state = const AsyncData(null);
  }

  Future<void> _saveTokens(AuthResponse response) async {
    final client = ref.read(dioClientProvider);
    client.setAccessToken(response.accessToken);
    await SecureStorage.setAccessToken(response.accessToken);
    await SecureStorage.setRefreshToken(response.refreshToken);
  }
}
