// notification_service.dart – medical grade with multi-reminder scheduling
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /* ---------- ORIGINAL API ---------- */

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
          'type': 'main', // main dose notification
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

  /* ---------- NEW MULTI-REMINDER API ---------- */

  /// Schedule all notifications for a medicine's complete treatment duration
  Future<void> scheduleAllNotificationsForMedicine({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> dailyTimes,
    required int durationDays,
  }) async {
    final startDate = DateTime.now();
    
    for (int day = 0; day < durationDays; day++) {
      for (int timeIndex = 0; timeIndex < dailyTimes.length; timeIndex++) {
        final time = dailyTimes[timeIndex];
        final doseDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day + day,
          time.hour,
          time.minute,
        );
        
        // Skip past times for today
        if (doseDateTime.isBefore(DateTime.now())) continue;
        
        final scheduleId = '${medicineId}_day${day}_time$timeIndex';
        
        await _scheduleAllRemindersForSingleDose(
          medicineId: medicineId,
          scheduleId: scheduleId,
          medicineName: medicineName,
          dosage: dosage,
          doseTime: doseDateTime,
        );
      }
    }
  }

  /// Reschedule all notifications for a medicine (cancel + schedule)
  Future<void> rescheduleAllForMedicine({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> dailyTimes,
    required int durationDays,
    required NotificationSettings settings,
  }) async {
    // First cancel all existing
    await cancelForMedicine(medicineId);
    
    // Then schedule new ones
    await scheduleAllNotificationsForMedicine(
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      dailyTimes: dailyTimes,
      durationDays: durationDays,
    );
  }

  /// Cancel all notifications for a specific dose (useful when marked as taken)
  Future<void> cancelAllRemindersForDose(String scheduleId) async {
    final list = await AwesomeNotifications().listScheduledNotifications();
    
    // Cancel main, pre, and missed dose notifications for this scheduleId
    for (final n in list.where((n) {
      final payload = n.content?.payload;
      return payload?['scheduleId'] == scheduleId ||
             payload?['scheduleId'] == '${scheduleId}_pre' ||
             payload?['scheduleId']?.startsWith('${scheduleId}_missed') == true;
    })) {
      await AwesomeNotifications().cancel(n.content!.id!);
    }
  }

  /* ---------- PRIVATE MULTI-REMINDER HELPERS ---------- */
  /// Schedule all reminders for a single dose using current saved settings
  Future<void> _scheduleAllRemindersForSingleDose({
    required String medicineId,
    required String scheduleId,
    required String medicineName,
    required String dosage,
    required DateTime doseTime,
  }) async {
    // 🔥 LEAN: Read settings directly from SharedPreferences
    final p = await SharedPreferences.getInstance();
    final reminderMinutesBefore = p.getInt('reminderMinutesBefore') ?? 0;
    final missedDoseReminders = p.getBool('missedDoseReminders') ?? true;
    final missedDoseDelayMinutes = p.getInt('missedDoseDelayMinutes') ?? 15;
    final maxMissedReminders = p.getInt('maxMissedReminders') ?? 2;

    final now = DateTime.now();

    // 1. Pre-reminder (if enabled)
    if (reminderMinutesBefore > 0) {
      final preTime = doseTime.subtract(Duration(minutes: reminderMinutesBefore));
      if (preTime.isAfter(now)) {
        await _scheduleNotification(
          id: _stableId('${scheduleId}_pre', preTime),
          time: preTime,
          title: 'Reminder: $medicineName in $reminderMinutesBefore min',
          body: 'Get ready for your $dosage dose',
          medicineId: medicineId,
          scheduleId: '${scheduleId}_pre',
          type: 'pre',
        );
      }
    }

    // 2. Main dose
    if (doseTime.isAfter(now)) {
      await schedule(
        medicineId: medicineId,
        scheduleId: scheduleId,
        name: medicineName,
        dosage: dosage,
        at: doseTime,
      );
    }

    // 3. Missed dose reminders (if enabled)
    if (missedDoseReminders) {
      for (int i = 1; i <= maxMissedReminders; i++) {
        final missedTime = doseTime.add(Duration(minutes: missedDoseDelayMinutes * i));
        if (missedTime.isAfter(now)) {
          await _scheduleNotification(
            id: _stableId('${scheduleId}_missed$i', missedTime),
            time: missedTime,
            title: 'Missed dose: $medicineName',
            body: 'Did you take your $dosage?',
            medicineId: medicineId,
            scheduleId: '${scheduleId}_missed$i',
            type: 'missed',
          );
        }
      }
    }
  }
  /// Generic notification scheduling helper
  Future<bool> _scheduleNotification({
    required int id,
    required DateTime time,
    required String title,
    required String body,
    required String medicineId,
    required String scheduleId,
    required String type,
  }) async {
    return AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: _medChannel,
        title: title,
        body: body,
        wakeUpScreen: true,
        category: NotificationCategory.Reminder,
        payload: {
          'medicineId': medicineId,
          'scheduleId': scheduleId,
          'date': time.toIso8601String().split('T').first,
          'type': type,
        },
      ),
      schedule: NotificationCalendar.fromDate(
        date: time,
        preciseAlarm: true,
        allowWhileIdle: true,
      ),
    );
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

  /// Cancel ALL scheduled notifications (for global toggle off)
  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  /// Get scheduled notifications grouped by medicine
  Future<Map<String, int>> getScheduledCountByMedicine() async {
    final list = await AwesomeNotifications().listScheduledNotifications();
    final counts = <String, int>{};
    
    for (final notification in list) {
      final medicineId = notification.content?.payload?['medicineId'];
      if (medicineId != null) {
        counts[medicineId] = (counts[medicineId] ?? 0) + 1;
      }
    }
    
    return counts;
  }

  /* ---------- INTERNALS ---------- */

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
    
    final type = p['type'];
    final scheduleId = p['scheduleId'];
    
    // If user interacts with main dose notification, 
    // cancel all related reminders (missed dose ones)
    if (type == 'main' && scheduleId != null) {
      await cancelAllRemindersForDose(scheduleId);
    }
    
    // TODO: log dose taken/missed here via your LogService
  }

  int _stableId(String scheduleId, DateTime at) =>
      '$scheduleId${at.year}${at.month}${at.day}${at.hour}${at.minute}'
          .hashCode
          .abs();
}

/// Enhanced settings model with multi-reminder options
class NotificationSettings {
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  
  // Pre-reminder settings
  final int reminderMinutesBefore; // 0 = disabled, 5, 10, 15, 30, 60
  
  // Missed dose settings
  final bool missedDoseReminders;
  final int missedDoseDelayMinutes; // 15, 30, 60 minutes between reminders
  final int maxMissedReminders; // 1, 2, 3 follow-ups

  const NotificationSettings({
    this.notificationsEnabled = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.reminderMinutesBefore = 0,
    this.missedDoseReminders = true,
    this.missedDoseDelayMinutes = 15,
    this.maxMissedReminders = 2,
  });
}