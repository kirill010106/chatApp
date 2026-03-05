// Push Notification Service Worker for ChatApp

self.addEventListener('push', function(event) {
  if (!event.data) return;

  let data;
  try {
    data = event.data.json();
  } catch (e) {
    data = {
      title: 'New Message',
      body: event.data.text(),
    };
  }

  const title = data.title || 'ChatApp';
  const options = {
    body: data.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data: {
      conversation_id: data.conversation_id || '',
      sender_id: data.sender_id || '',
    },
    tag: 'chatapp-' + (data.conversation_id || 'default'),
    renotify: true,
    requireInteraction: false,
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  const data = event.notification.data || {};
  const conversationId = data.conversation_id;

  let url = '/';
  if (conversationId) {
    url = '/#/chat/' + conversationId;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(windowClients) {
      // Focus existing window if available
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if ('focus' in client) {
          client.focus();
          if (conversationId) {
            client.navigate(url);
          }
          return;
        }
      }
      // Open new window
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});

self.addEventListener('pushsubscriptionchange', function(event) {
  // Handle subscription expiration - re-subscribe
  event.waitUntil(
    self.registration.pushManager.subscribe(event.oldSubscription.options)
      .then(function(subscription) {
        // Ideally notify the server about the new subscription
        // For now, the client will re-subscribe on next load
        console.log('Push subscription renewed');
      })
  );
});
