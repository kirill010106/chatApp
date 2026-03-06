import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/ws_service.dart';

final wsServiceProvider = Provider<WsService>((ref) {
  final wsService = WsService();

  // Track whether we already attempted connection for the current user.
  String? connectedUserId;

  // Listen for auth state changes (including initial load)
  ref.listen(authStateProvider, (previous, next) async {
    final user = next.value;
    if (user != null) {
      // Only connect if user changed (login or fresh load)
      if (connectedUserId == user.id) return;
      connectedUserId = user.id;
      final token = await SecureStorage.getAccessToken();
      if (token != null) {
        wsService.connect(token);
      }
    } else {
      connectedUserId = null;
      wsService.disconnect();
    }
  }, fireImmediately: true);

  ref.onDispose(() => wsService.dispose());
  return wsService;
});
