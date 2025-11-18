// firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBiJndUL1MP4KAoadNwTaZdvL8sPt0Tqgw",
  authDomain: "calamity-report.firebaseapp.com",
  projectId: "calamity-report",
  storageBucket: "calamity-report.firebasestorage.app",
  messagingSenderId: "522642764339",
  appId: "1:522642764339:web:603214990a762079fe6946",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification.body || '',
    icon: payload.notification.icon || '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] Notification click received.');
  
  event.notification.close();
  
  // Handle navigation based on notification data
  event.waitUntil(
    clients.openWindow(event.notification.data?.url || '/')
  );
});
