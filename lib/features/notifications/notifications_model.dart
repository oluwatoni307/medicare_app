// notification_model.dart
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String medicineId;
  final String scheduleId;
  final bool isActive;
  final NotificationType type;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    required this.medicineId,
    required this.scheduleId,
    this.isActive = true,
    this.type = NotificationType.medicineReminder,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? scheduledTime,
    String? medicineId,
    String? scheduleId,
    bool? isActive,
    NotificationType? type,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      medicineId: medicineId ?? this.medicineId,
      scheduleId: scheduleId ?? this.scheduleId,
      isActive: isActive ?? this.isActive,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
      'medicineId': medicineId,
      'scheduleId': scheduleId,
      'isActive': isActive,
      'type': type.name,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      medicineId: json['medicineId'],
      scheduleId: json['scheduleId'],
      isActive: json['isActive'] ?? true,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.medicineReminder,
      ),
    );
  }
}

enum NotificationType {
  medicineReminder,
  missedDose,
  refillReminder,
}

// schedule_notification_model.dart
class ScheduleNotificationModel {
  final String scheduleId;
  final String medicineId;
  final String medicineName;
  final String dosage;
  final String time;
  final DateTime startDate;
  final DateTime endDate;
  final List<NotificationModel> notifications;

  const ScheduleNotificationModel({
    required this.scheduleId,
    required this.medicineId,
    required this.medicineName,
    required this.dosage,
    required this.time,
    required this.startDate,
    required this.endDate,
    this.notifications = const [],
  });

  ScheduleNotificationModel copyWith({
    String? scheduleId,
    String? medicineId,
    String? medicineName,
    String? dosage,
    String? time,
    DateTime? startDate,
    DateTime? endDate,
    List<NotificationModel>? notifications,
  }) {
    return ScheduleNotificationModel(
      scheduleId: scheduleId ?? this.scheduleId,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notifications: notifications ?? this.notifications,
    );
  }

  bool get isActive => DateTime.now().isBefore(endDate);
  
  int get totalDays => endDate.difference(startDate).inDays + 1;
}

// notification_settings_model.dart
class NotificationSettingsModel {
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int reminderMinutesBefore;
  final bool missedDoseReminders;
  final int missedDoseDelayMinutes;

  const NotificationSettingsModel({
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.reminderMinutesBefore = 0,
    this.missedDoseReminders = true,
    this.missedDoseDelayMinutes = 30,
  });

  NotificationSettingsModel copyWith({
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? reminderMinutesBefore,
    bool? missedDoseReminders,
    int? missedDoseDelayMinutes,
  }) {
    return NotificationSettingsModel(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      missedDoseReminders: missedDoseReminders ?? this.missedDoseReminders,
      missedDoseDelayMinutes: missedDoseDelayMinutes ?? this.missedDoseDelayMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
      'missedDoseReminders': missedDoseReminders,
      'missedDoseDelayMinutes': missedDoseDelayMinutes,
    };
  }

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      soundEnabled: json['soundEnabled'] ?? true,
      vibrationEnabled: json['vibrationEnabled'] ?? true,
      reminderMinutesBefore: json['reminderMinutesBefore'] ?? 0,
      missedDoseReminders: json['missedDoseReminders'] ?? true,
      missedDoseDelayMinutes: json['missedDoseDelayMinutes'] ?? 30,
    );
  }
}