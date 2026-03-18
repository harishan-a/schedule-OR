// Give the service worker access to Firebase Messaging.
// Note that you can only use Firebase Messaging here. Other Firebase libraries
// are not available in the service worker.
importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js');

// Initialize the Firebase app in the service worker:
firebase.initializeApp({
  apiKey: 'AIzaSyBsbwEecRerphtgmxGO16pKRXLEI93LkCg',
  authDomain: 'flutter-orscheduler.firebaseapp.com',
  projectId: 'flutter-orscheduler',
  storageBucket: 'flutter-orscheduler.appspot.com',
  messagingSenderId: '515203068904',
  appId: '1:515203068904:web:6a5eaad6676c1a79836a5d',
  measurementId: 'G-JPSEZ7MRQ3'
});

// Get Firebase messaging instance
const messaging = firebase.messaging();

// Background push handler
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Customize notification if needed
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
}); 