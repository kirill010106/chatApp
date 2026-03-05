import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/ws_service.dart';

final wsServiceProvider = Provider<WsService>((ref) {
  final wsService = WsService();

  // Connect if already authenticated
  Future<void> tryConnect() async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      wsService.connect(token);
    }
  }

  // Listen for auth state changes (including initial load)
  ref.listen(authStateProvider, (previous, next) async {
    if (next.value != null) {
      await tryConnect();
    } else {
      wsService.disconnect();
    }
  }, fireImmediately: true);

  ref.onDispose(() => wsService.dispose());
  return wsService;
});
