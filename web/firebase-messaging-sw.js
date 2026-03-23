importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  databaseURL: 'https://aco-plus-fa455.firebaseio.com',
  apiKey: 'AIzaSyArDF3DcSwhocSFg0R_9U2y2YTS7NTzCXA',
  appId: '1:210867609065:web:9f428880737f7af2bc3f78',
  messagingSenderId: '210867609065',
  projectId: 'aco-plus-fa455',
  authDomain: 'aco-plus-fa455.firebaseapp.com',
  storageBucket: 'aco-plus-fa455.appspot.com',
  measurementId: 'G-SVFPP99C61',
});
// Necessary to receive background messages:
const messaging = firebase.messaging();

// Optional:
messaging.onBackgroundMessage((m) => {
  console.log("onBackgroundMessage", m);
});
