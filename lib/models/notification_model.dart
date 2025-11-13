class NotificationModel {
  final String title;
  final String body;
  final String type;
  final String timestamp;

  NotificationModel({
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      title: json['title'],
      body: json['body'],
      type: json['type'],
      timestamp: json['timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'timestamp': timestamp,
    };
  }
}