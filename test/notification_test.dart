import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void simulateNotification(RemoteMessage message) {
  final notification = message.notification;
  final data = message.data;

  if (notification != null) {
    print('Simulated notification received: ${notification.title}');
    print('Notification Body: ${notification.body}');
  }

  if (data.isNotEmpty) {
    print('Notification Data: $data');
  }
}

void main() {
  test('Simulate Notification Test', () {
    // Create a mock RemoteMessage object
    final mockMessage = RemoteMessage(
      notification: RemoteNotification(
        title: 'Test Notification',
        body: 'This is a simulated notification.',
      ),
      data: {
        'screen': 'history',
      },
    );

    simulateNotification(mockMessage);
    expect(true, isTrue); // Dummy assertion to ensure the test runs
  });
}