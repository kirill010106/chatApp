// Push notification helper for Flutter Web
// Exposes functions that Dart can call via JS interop

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding)
    .replace(/\-/g, '+')
    .replace(/_/g, '/');
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

/**
 * Register the push service worker, request permission, subscribe, 
 * and return the subscription as a JSON object.
 * @param {string} vapidPublicKey - The VAPID public key from the server
 * @returns {Promise<{endpoint: string, p256dh: string, auth: string}|null>}
 */
async function subscribeToPush(vapidPublicKey) {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
    console.warn('Push not supported');
    return null;
  }

  try {
    const registration = await navigator.serviceWorker.register('push-sw.js');
    await navigator.serviceWorker.ready;

    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      console.warn('Notification permission denied');
      return null;
    }

    // Reuse existing subscription if available (avoids duplicate DB entries)
    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
      });
    }

    const subJson = subscription.toJSON();
    return {
      endpoint: subJson.endpoint,
      p256dh: subJson.keys.p256dh,
      auth: subJson.keys.auth,
    };
  } catch (e) {
    console.error('Push subscribe error:', e);
    return null;
  }
}

/**
 * Unsubscribe from push notifications.
 * @returns {Promise<string|null>} The endpoint that was unsubscribed, or null.
 */
async function unsubscribeFromPush() {
  if (!('serviceWorker' in navigator)) return null;

  try {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    if (subscription) {
      const endpoint = subscription.endpoint;
      await subscription.unsubscribe();
      return endpoint;
    }
    return null;
  } catch (e) {
    console.error('Push unsubscribe error:', e);
    return null;
  }
}

/**
 * Check if push notifications are supported and permitted.
 * @returns {string} 'granted', 'denied', 'default', or 'unsupported'
 */
function getPushPermissionStatus() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
    return 'unsupported';
  }
  return Notification.permission;
}
