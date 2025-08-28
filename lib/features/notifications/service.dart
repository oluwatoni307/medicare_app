// notification_service.dart – medical grade with lean additions
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _medChannel = 'medicine_critical';

  Future<void> init() async {
    // 1. Ask once for every permission we need
    await _requestPermissions();

    // 2. One high-priority channel
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: _medChannel,
          channelName: 'Medicine Reminders',
          channelDescription: 'Critical medication alerts',
          importance: NotificationImportance.Max,
          defaultColor: Colors.red,
          ledColor: Colors.white,
          playSound: true,
          enableVibration: true,
          criticalAlerts: true,           // iOS "critical" tier
          channelShowBadge: true,
          onlyAlertOnce: false,
        ),
      ],
    );

    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onAction,
    );
  }

  /* ---------- existing API ---------- */

  Future<bool> schedule({
    required String medicineId,
    required String scheduleId,
    required String name,
    required String dosage,
    required DateTime at,
  }) async {
    final id = _stableId(scheduleId, at);   // deterministic
    return AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: _medChannel,
        title: 'Time for $name',
        body: dosage,
        wakeUpScreen: true,
        category: NotificationCategory.Reminder,
        payload: {
          'medicineId': medicineId,
          'scheduleId': scheduleId,
          'date': at.toIso8601String().split('T').first,
        },
      ),
      schedule: NotificationCalendar.fromDate(
        date: at,
        preciseAlarm: true,          // exact on Android 12+
        allowWhileIdle: true,
      ),
    );
  }

  Future<void> cancelForMedicine(String medicineId) async {
    final list = await AwesomeNotifications().listScheduledNotifications();
    for (final n in list.where((n) =>
        n.content?.payload?['medicineId'] == medicineId)) {
      await AwesomeNotifications().cancel(n.content!.id!);
    }
  }

  /* ---------- LEAN ADDITIONS ---------- */

  /// Check if we have all needed permissions
  Future<bool> get hasPermissions async {
    final notifications = await AwesomeNotifications().isNotificationAllowed();
    final exactAlarm = await Permission.scheduleExactAlarm.isGranted;
    return notifications && exactAlarm;
  }

  /// Send immediate test notification
  Future<bool> sendTest() async {
    return AwesomeNotifications().createNotification(
      content: NotificationContent(
      id: 999999, // Simple fixed ID
        channelKey: _medChannel,
        title: '💊 Test Reminder',
        body: 'This is how your medicine reminders will look',
        wakeUpScreen: true,
        category: NotificationCategory.Reminder,
      ),
    );
  }

  /// Count scheduled notifications
  Future<int> get scheduledCount async {
    final list = await AwesomeNotifications().listScheduledNotifications();
    return list.length;
  }

  /* ---------- internals ---------- */

  Future<void> _requestPermissions() async {
    // Notifications
    if (!await AwesomeNotifications().isNotificationAllowed()) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    // Android 12+ exact alarms
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> _onAction(ReceivedAction a) async {
    final p = a.payload;
    if (p == null) return;
    // TODO: log dose taken/missed here via your LogService
  }

  int _stableId(String scheduleId, DateTime at) =>
      '$scheduleId${at.year}${at.month}${at.day}${at.hour}${at.minute}'
          .hashCode
          .abs();
}