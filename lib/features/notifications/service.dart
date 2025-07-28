// ignore_for_file: depend_on_referenced_packages, duplicate_import

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notifications_model.dart';
import 'package:timezone/timezone.dart';
import 'dart:convert';

/// === NOTIFICATION SERVICE OVERVIEW ===
/// Purpose: Core notification business logic and system integration
/// Dependencies: flutter_local_notifications, shared_preferences, database
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  NotificationSettingsModel _settings = const NotificationSettingsModel();
  
  // === PUBLIC API ===
  
  /// Initialize notification system and permissions
  Future<bool> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    if (initialized == true) {
      await _loadSettings();
    }
    
    return initialized ?? false;
  }

  /// Request notification permissions from system
  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    
    if (status.isGranted) {
      // For iOS, request additional permissions
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return true;
    }
    
    return false;
  }

  /// Schedule all notifications for a medicine schedule
  Future<void> scheduleNotificationsForSchedule(ScheduleNotificationModel schedule) async {
    if (!_settings.notificationsEnabled) return;

    await _cancelNotificationsForSchedule(schedule.scheduleId);
    
    final notifications = _generateNotificationsForSchedule(schedule);
    
    for (final notification in notifications) {
      await _scheduleNotification(notification);
    }
  }

  /// Cancel all notifications for a specific schedule
  Future<void> cancelNotificationsForSchedule(String scheduleId) async {
    await _cancelNotificationsForSchedule(scheduleId);
  }

  /// Cancel all notifications for a medicine (when medicine is deleted)
  Future<void> cancelNotificationsForMedicine(String medicineId) async {
    final pendingNotifications = await _notifications.pendingNotificationRequests();
    
    for (final notification in pendingNotifications) {
      final payload = notification.payload;
      if (payload != null) {
        final data = Map<String, dynamic>.from(
          Uri.splitQueryString(payload)
        );
        if (data['medicineId'] == medicineId) {
          await _notifications.cancel(notification.id);
        }
      }
    }
  }

  /// Update notification settings
  Future<void> updateSettings(NotificationSettingsModel settings) async {
    _settings = settings;
    await _saveSettings();
    
    if (!settings.notificationsEnabled) {
      await cancelAllNotifications();
    }
  }

  /// Get current notification settings
  NotificationSettingsModel get settings => _settings;

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get pending notifications count
  Future<int> getPendingNotificationsCount() async {
    final pending = await _notifications.pendingNotificationRequests();
    return pending.length;
  }

  // === INTERNAL LOGIC ===

  /// Generate notification models from schedule data
  List<NotificationModel> _generateNotificationsForSchedule(ScheduleNotificationModel schedule) {
    final notifications = <NotificationModel>[];
    final scheduleTime = _parseTime(schedule.time);
    
    if (scheduleTime == null) return notifications;

    DateTime currentDate = schedule.startDate;
    
    while (currentDate.isBefore(schedule.endDate) || currentDate.isAtSameMomentAs(schedule.endDate)) {
      final notificationTime = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        scheduleTime.hour,
        scheduleTime.minute,
      ).subtract(Duration(minutes: _settings.reminderMinutesBefore));

      // Only schedule future notifications
      if (notificationTime.isAfter(DateTime.now())) {
        notifications.add(NotificationModel(
          id: '${schedule.scheduleId}_${currentDate.millisecondsSinceEpoch}',
          title: 'Time for ${schedule.medicineName}',
          body: 'Take ${schedule.dosage}',
          scheduledTime: notificationTime,
          medicineId: schedule.medicineId,
          scheduleId: schedule.scheduleId,
        ));
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return notifications;
  }

  /// Schedule a single notification with the system
  Future<void> _scheduleNotification(NotificationModel notification) async {
    final androidDetails = AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine Reminders',
      channelDescription: 'Notifications for medicine schedules',
      importance: Importance.high,
      priority: Priority.high,
      playSound: _settings.soundEnabled,
      enableVibration: _settings.vibrationEnabled,
    );

    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = Uri(queryParameters: {
      'medicineId': notification.medicineId,
      'scheduleId': notification.scheduleId,
      'notificationId': notification.id,
    }).query;

    await _notifications.zonedSchedule(
  notification.id.hashCode,
  notification.title,
  notification.body,
  _convertToTimezone(notification.scheduledTime),
  details,
  matchDateTimeComponents: DateTimeComponents.time, // or DateTimeComponents.dateAndTime
  payload: payload,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
);
  }

  /// Cancel notifications for specific schedule
  Future<void> _cancelNotificationsForSchedule(String scheduleId) async {
    final pendingNotifications = await _notifications.pendingNotificationRequests();
    
    for (final notification in pendingNotifications) {
      final payload = notification.payload;
      if (payload != null) {
        final data = Map<String, dynamic>.from(
          Uri.splitQueryString(payload)
        );
        if (data['scheduleId'] == scheduleId) {
          await _notifications.cancel(notification.id);
        }
      }
    }
  }

  /// Parse time string to TimeOfDay
  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      // Invalid time format
    }
    return null;
  }

  /// Convert DateTime to TZDateTime for scheduling
  TZDateTime _convertToTimezone(DateTime dateTime) {
    // This assumes you're using timezone package
    // You may need to adjust based on your timezone handling
    return TZDateTime.from(dateTime, getLocation('UTC'));
  }

  /// Handle notification tap
  void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      final data = Map<String, dynamic>.from(
        Uri.splitQueryString(payload)
      );
      
      // Navigate to medicine detail or mark as taken
      // This would integrate with your navigation service
      _handleMedicineNotificationTap(
        data['medicineId'],
        data['scheduleId'],
        data['notificationId'],
      );
    }
  }

  /// Handle medicine notification interaction
  void _handleMedicineNotificationTap(String? medicineId, String? scheduleId, String? notificationId) {
    // Implement navigation or action handling
    // This would call your navigation service or update dose tracking
  }

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('notification_settings');
    
    if (settingsJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(settingsJson);
        _settings = NotificationSettingsModel.fromJson(data);
      } catch (e) {
        // Use default settings if loading fails
      }
    }
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_settings', jsonEncode(_settings.toJson()));
  }
}