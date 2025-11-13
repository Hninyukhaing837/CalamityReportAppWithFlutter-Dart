importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBiJndUL1MP4KAoadNwTaZdvL8sPt0Tqgw",
  authDomain: "calamity-report.firebaseapp.com",
  projectId: "calamity-report",
  storageBucket: "calamity-report.firebasestorage.app",
  messagingSenderId: "522642764339",
  appId: "1:522642764339:web:603214990a762079fe6946",
});

const messaging = firebase.messaging();