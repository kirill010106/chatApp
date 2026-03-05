import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../../core/network/dio_client.dart';

@JS('subscribeToPush')
external JSPromise<JSObject?> _subscribeToPush(JSString vapidPublicKey);

@JS('unsubscribeFromPush')
external JSPromise<JSString?> _unsubscribeFromPush();

@JS('getPushPermissionStatus')
external JSString _getPushPermissionStatus();

class PushNotificationService {
  final DioClient _client;

  PushNotificationService(this._client);

  /// Check if push notifications are supported and get permission status.
  String getPermissionStatus() {
    return _getPushPermissionStatus().toDart;
  }

  /// Initialize push notifications: register SW, request permission, subscribe.
  Future<bool> initialize() async {
    try {
      final status = getPermissionStatus();
      if (status == 'unsupported' || status == 'denied') return false;

      // Get VAPID public key from server
      final vapidKey = await _getVAPIDPublicKey();
      if (vapidKey == null || vapidKey.isEmpty) return false;

      // Subscribe via JS helper (registers SW, requests permission, subscribes)
      final result = await _subscribeToPush(vapidKey.toJS).toDart;
      if (result == null) return false;

      // Extract subscription data using js_interop_unsafe
      final endpoint =
          (result['endpoint'] as JSString).toDart;
      final p256dh =
          (result['p256dh'] as JSString).toDart;
      final auth =
          (result['auth'] as JSString).toDart;

      // Send subscription to backend
      await _client.post(
        '/api/v1/push/subscribe',
        data: {
          'endpoint': endpoint,
          'p256dh': p256dh,
          'auth': auth,
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Unsubscribe from push notifications.
  Future<void> unsubscribe() async {
    try {
      final endpoint = await _unsubscribeFromPush().toDart;
      if (endpoint != null) {
        await _client.post(
          '/api/v1/push/unsubscribe',
          data: {'endpoint': endpoint.toDart},
        );
      }
    } catch (_) {}
  }

  Future<String?> _getVAPIDPublicKey() async {
    try {
      final response = await _client.get('/api/v1/push/vapid-key');
      final data = response.data as Map<String, dynamic>;
      return data['public_key'] as String?;
    } catch (e) {
      return null;
    }
  }
}
