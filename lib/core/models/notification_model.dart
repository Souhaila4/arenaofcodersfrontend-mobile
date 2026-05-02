/// In-app notification (e.g. hackathon match)
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final String? competitionId;
  final bool read;
  final DateTime createdAt;
  final NotificationCompetition? competition;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.competitionId,
    this.read = false,
    required this.createdAt,
    this.competition,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    return AppNotification(
      id: json['id'] as String,
      type: (json['type'] as String?) ?? '',
      title: json['title'] as String,
      body: json['body'] as String?,
      competitionId: json['competitionId'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: createdAtRaw != null ? DateTime.parse(createdAtRaw.toString()) : DateTime.now(),
      competition: json['competition'] != null
          ? NotificationCompetition.fromJson(json['competition'] as Map<String, dynamic>)
          : null,
    );
  }
}

class NotificationCompetition {
  final String id;
  final String title;
  final String? status;
  final String? specialty;
  final DateTime? startDate;
  final DateTime? endDate;

  NotificationCompetition({
    required this.id,
    required this.title,
    this.status,
    this.specialty,
    this.startDate,
    this.endDate,
  });

  factory NotificationCompetition.fromJson(Map<String, dynamic> json) {
    return NotificationCompetition(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String?,
      specialty: json['specialty'] as String?,
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
    );
  }
}

class NotificationsResponse {
  final List<AppNotification> data;
  final int unreadCount;

  NotificationsResponse({required this.data, required this.unreadCount});

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    return NotificationsResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}
