import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/push_notification_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.read(dioClientProvider));
});

/// Provider that initializes push notifications when the user is authenticated.
final pushInitProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return false;

  final pushService = ref.read(pushNotificationServiceProvider);
  return pushService.initialize();
});
