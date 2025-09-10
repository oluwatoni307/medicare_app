// notification_service.dart – Android-only, rolling-window, 2 h timeout
import 'dart:convert';
// import 'dart:math' as math;
import 'dart:typed_data';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
// your existing log feature
import '../log/service.dart';
import '../log/log_model.dart' as feature;

/// CHANGED: top-level background handler required for delivered actions
/// (ensures callbacks fire when app is backgrounded/terminated)
@pragma('vm:entry-point')
Future<void> onActionReceivedBackground(ReceivedAction action) async {
  // forward to singleton; _onAction stays instance-level for testability, but background entry-point must be top-level
  await NotificationService.instance._onAction(action);
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  static const _medChannel = 'medicine_critical';

  final LogService _logService = LogService();
  bool _channelInitialized = false;

  /* ================================================================
                           PUBLIC ENTRY
     ================================================================ */

  Future<void> init() async {
    try {
      await _logService.init();
      debugPrint('📱 Initialising notification service...');
      // Make sure channel exists before registering listeners/scheduling
      await _initialiseChannels();

      /// CHANGED: register top-level background handler so actions work when app is killed
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: onActionReceivedBackground,
      );

      debugPrint('📱 Requesting permissions...');
      final permissionsGranted = await requestPermissions();
      debugPrint('📱 Permissions granted: $permissionsGranted');
      await debugNotificationState();
    } catch (e) {
      debugPrint('❌ Notification service init failed: $e');
      rethrow;
    }
  }

  Future<bool> setupNotificationsForUser() async {
    if (!await requestPermissions()) return false;
    await requestBatteryOptimization();
    return await sendTestNotification();
  }

  /* ================================================================
                          PERMISSIONS
     ================================================================ */

  Future<bool> requestPermissions() async {
    // 1. basic notification (Android-13+)
    if (!await AwesomeNotifications().isNotificationAllowed()) {
      final ok = await AwesomeNotifications().requestPermissionToSendNotifications();
      if (!ok) return false;
    }
    // 2. exact-alarm (Android-12+)
    if (await Permission.scheduleExactAlarm.isDenied) {
      final status = await Permission.scheduleExactAlarm.request();
      if (!status.isGranted) return false;
    }
    return true;
  }

  Future<bool> requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isDenied) {
      final result = await Permission.ignoreBatteryOptimizations.request();
      return result.isGranted;
    }
    return status.isGranted;
  }

  /* ================================================================
                        ROLLING-WINDOW SCHEDULER
     ================================================================ */

  /// View-model calls this – we schedule ONLY the next single alarm
  Future<void> scheduleAllTreatmentReminders({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> dailyTimes,
    required int durationDays,
  }) async {
    final now = DateTime.now();
    DateTime? next;
    for (int d = 0; d < durationDays && next == null; d++) {
      for (final tod in dailyTimes) {
        // safer day construction
        final baseDay = DateTime(now.year, now.month, now.day).add(Duration(days: d));
        final candidate = DateTime(baseDay.year, baseDay.month, baseDay.day, tod.hour, tod.minute);
        if (candidate.isAfter(now)) {
          next = candidate;
          break;
        }
      }
    }
    if (next == null) return;

    // 1. schedule the single alarm
    final ok = await scheduleSimpleReminder(
      medicineId: medicineId,
      scheduleId: '${medicineId}_rolling',
      medicineName: medicineName,
      dosage: dosage,
      doseTime: next,
    );
    if (!ok) return;

    // 2. store the remaining plan
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rolling_plan_$medicineId', jsonEncode({
      'medicineName': medicineName,
      'dosage': dosage,
      'dailyTimes': dailyTimes.map((t) => '${t.hour}:${t.minute}').toList(),
      'durationDays': durationDays,
      'startDay': now.toIso8601String().split('T').first,
    }));
  }

  /// Schedule ONE notification with 2-hour timeout and full-screen intent
  Future<bool> scheduleSimpleReminder({
    required String medicineId,
    required String scheduleId,
    required String medicineName,
    required String dosage,
    required DateTime doseTime,
  }) async {
    if (!await hasPermissions) return false;
    await _ensureChannelExists();

    final id = _generateStableId(scheduleId, doseTime);
    if (doseTime.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) return false;

    try {
      // CHANGED: add explicit action buttons so TAKEN/MISSED are available even when app is backgrounded
      final created = await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: _medChannel,
          title: '💊 $medicineName',
          body: 'Time for your $dosage dose',
          summary: 'Medicine Reminder',
          wakeUpScreen: true,
          fullScreenIntent: true,
          category: NotificationCategory.Alarm,
          payload: {
            'medicineId': medicineId,
            'scheduleId': scheduleId,
            'date': doseTime.toIso8601String().split('T').first,
            'medicineName': medicineName,
            'dosage': dosage,
          },
          autoDismissible: true,
          showWhen: true,
          displayOnBackground: true,
          displayOnForeground: true,
          notificationLayout: NotificationLayout.Default,
          timeoutAfter: const Duration(hours: 2), // 2-hour window
        ),
        actionButtons: [
          NotificationActionButton(key: 'TAKEN', label: 'Taken', actionType: ActionType.Default),
          NotificationActionButton(key: 'MISSED', label: 'Missed', actionType: ActionType.Default),
        ],
        schedule: NotificationCalendar.fromDate(
          date: doseTime,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );

      // CHANGED: schedule a fallback follow-up notification at doseTime + 2 hours
      // This is a resilience measure — if the dismiss callback is not delivered when the app is killed,
      // the follow-up notification will appear and serve as a visible reminder / fallback.
      // We won't fail the main scheduling if this follow-up fails.
      try {
        final followTime = doseTime.add(const Duration(hours: 2));
        final followId = _generateStableId('${scheduleId}_auto_miss', followTime);
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: followId,
            channelKey: _medChannel,
            title: '⏰ Missed: $medicineName',
            body: 'Missed dose from ${doseTime.hour.toString().padLeft(2,'0')}:${doseTime.minute.toString().padLeft(2,'0')}',
            summary: 'Missed dose fallback',
            wakeUpScreen: false,
            fullScreenIntent: false,
            category: NotificationCategory.Reminder,
            payload: {
              'medicineId': medicineId,
              'scheduleId': scheduleId,
              'date': doseTime.toIso8601String().split('T').first,
              'medicineName': medicineName,
              'dosage': dosage,
              'autoMiss': 'true',
            },
            autoDismissible: true,
            showWhen: true,
            displayOnBackground: true,
            displayOnForeground: true,
            notificationLayout: NotificationLayout.Default,
          ),
           actionButtons: [
          NotificationActionButton(key: 'TAKEN', label: 'Taken', actionType: ActionType.Default),
          NotificationActionButton(key: 'MISSED', label: 'Missed', actionType: ActionType.Default),
        ],
          schedule: NotificationCalendar.fromDate(
            date: followTime,
            preciseAlarm: true,
            allowWhileIdle: true,
          ),
        );
      } catch (e) {
        debugPrint('⚠️ follow-up auto-miss scheduling failed: $e');
      }

      return created;
    } catch (e) {
      debugPrint('❌ scheduleSimpleReminder exception: $e');
      return false;
    }
  }

  /* ================================================================
                        ACTION HANDLER  (3 cases)
     ================================================================ */

  /// NOTE: this method remains an instance method to preserve testability and
  /// to avoid changing external usage. It *is* invoked from the top-level
  /// `onActionReceivedBackground` entry-point when the OS delivers events.
  Future<void> _onAction(ReceivedAction action) async {
    final payload = action.payload;
    if (payload == null) return;

    final medicineId = payload['medicineId']!;
    final date = payload['date']!;
    final medicineName = payload['medicineName'] ?? 'Medicine';

    // 1. explicit TAKEN button
    if (action.buttonKeyPressed == 'TAKEN') {
      await _logService.saveLog(
        scheduleId: payload['scheduleId']!,
        status: feature.LogStatus.taken,
        date: date,
      );
      await _showToast('✅ $medicineName logged as taken');
      await _rescheduleNext(medicineId);
      return;
    }

    // 2. explicit MISSED button
    if (action.buttonKeyPressed == 'MISSED') {
      await _logService.saveLog(
        scheduleId: payload['scheduleId']!,
        status: feature.LogStatus.missed,
        date: date,
      );
      await _showToast('⚠️ $medicineName marked missed');
      await _rescheduleNext(medicineId);
      return;
    }
  }

  /* ================================================================
                        RESCHEDULE NEXT DOSE
     ================================================================ */

  Future<void> _rescheduleNext(String medicineId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('rolling_plan_$medicineId');
    if (raw == null) return;
    final plan = jsonDecode(raw) as Map<String, dynamic>;

    final times = (plan['dailyTimes'] as List)
        .map((s) => TimeOfDay(hour: int.parse(s.split(':')[0]), minute: int.parse(s.split(':')[1])))
        .toList();
    final startDate = DateTime.parse(plan['startDay'] as String);
    final elapsedDays = DateTime.now().difference(startDate).inDays;
    final remainingDays = (plan['durationDays'] as int) - elapsedDays;

    if (remainingDays <= 0) {
      await prefs.remove('rolling_plan_$medicineId');
      return;
    }

    await scheduleAllTreatmentReminders(
      medicineId: medicineId,
      medicineName: plan['medicineName'],
      dosage: plan['dosage'],
      dailyTimes: times,
      durationDays: remainingDays,
    );
  }

  /* ================================================================
                        BOOT SUPPORT
     ================================================================ */

  static Future<void> rescheduleAllOnBoot() async {
    final prefs = await SharedPreferences.getInstance();

    // CHANGED: ensure channels are created before rescheduling on boot
    try {
      await instance._ensureChannelExists();
    } catch (e) {
      debugPrint('⚠️ Failed to ensure channels on boot: $e');
    }

    for (final key in prefs.getKeys().where((k) => k.startsWith('rolling_plan_'))) {
      final medicineId = key.replaceFirst('rolling_plan_', '');
      await instance._rescheduleNext(medicineId);
    }
  }

  /* ================================================================
                        UTILITIES
     ================================================================ */

  Future<void> _showToast(String msg) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch,
        channelKey: _medChannel,
        title: '💊 MedTracker',
        body: msg,
        autoDismissible: true,
        showWhen: false,
        timeoutAfter: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> sendTestNotification() async =>
      scheduleSimpleReminder(
        medicineId: 'test',
        scheduleId: 'test_schedule',
        medicineName: 'Test Medicine',
        dosage: '1 tablet',
        doseTime: DateTime.now().add(const Duration(seconds: 5)),
      );

  Future<int> get scheduledCount async {
    final list = await AwesomeNotifications().listScheduledNotifications();
    return list.length;
  }

  Future<void> cancelForMedicine(String medicineId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rolling_plan_$medicineId');
    final list = await AwesomeNotifications().listScheduledNotifications();
    for (final n in list) {
      if (n.content?.payload?['medicineId'] == medicineId) {
        await AwesomeNotifications().cancel(n.content!.id!);
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith('rolling_plan_'))) {
      await prefs.remove(k);
    }
    await AwesomeNotifications().cancelAll();
  }

  /* ----------------------------------------------------------
        MISSING METHODS RESTORED – exact signatures you had
     ---------------------------------------------------------- */

  Future<Map<String, int>> getScheduledCountByMedicine() async {
    final list = await AwesomeNotifications().listScheduledNotifications();
    final counts = <String, int>{};
    for (final n in list) {
      final id = n.content?.payload?['medicineId'];
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<bool> sendTest() async => sendTestNotification();

  Future<void> rescheduleAllForMedicine({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> dailyTimes,
    required int durationDays,
    required NotificationSettings settings,
  }) async {
    await cancelForMedicine(medicineId);
    if (settings.notificationsEnabled) {
      await scheduleAllTreatmentReminders(
        medicineId: medicineId,
        medicineName: medicineName,
        dosage: dosage,
        dailyTimes: dailyTimes,
        durationDays: durationDays,
      );
    }
  }

  /* ================================================================
                        PERMISSION / HEALTH
     ================================================================ */

  Future<bool> get hasPermissions async {
    final notif = await AwesomeNotifications().isNotificationAllowed();
    final exact = await Permission.scheduleExactAlarm.isGranted;
    return notif && exact;
  }

  Future<Map<String, bool>> get androidPermissionStatus async => {
        'notifications': await AwesomeNotifications().isNotificationAllowed(),
        'exactAlarm': await Permission.scheduleExactAlarm.isGranted,
        'batteryOptimization': await Permission.ignoreBatteryOptimizations.isGranted,
      };

  Future<Map<String, dynamic>> getDiagnostics() async {
    final perms = await androidPermissionStatus;
    final count = await scheduledCount;
    return {
      'permissions': perms,
      'scheduledCount': count,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> debugNotificationState() async {
    final diagnostics = await getDiagnostics();
    debugPrint('🔍 NOTIFICATION DIAGNOSTICS: $diagnostics');
  }

  /* ================================================================
                        PRIVATE HELPERS
     ================================================================ */

  int _generateStableId(String scheduleId, DateTime dt) =>
      '$scheduleId${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}'
          .hashCode
          .abs();

  Future<void> _ensureChannelExists() async {
    if (_channelInitialized) return;
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: _medChannel,
          channelName: 'Medicine Reminders',
          channelDescription: 'Critical medication dose reminders',
          importance: NotificationImportance.Max,
          defaultColor: Colors.blue,
          ledColor: Colors.white,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
          channelShowBadge: true,
          onlyAlertOnce: false,
          locked: true,
          defaultRingtoneType: DefaultRingtoneType.Alarm,
          enableLights: true,
          criticalAlerts: true,
        ),
      ],
    );
    _channelInitialized = true;
  }

  Future<void> _initialiseChannels() => _ensureChannelExists();
}

/* ================================================================
                      BACKWARD-COMPAT SETTINGS MODEL
     ================================================================ */

class NotificationSettings {
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int reminderMinutesBefore;
  final bool missedDoseReminders;
  final int missedDoseDelayMinutes;
  final int maxMissedReminders;

  const NotificationSettings({
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.reminderMinutesBefore = 0,
    this.missedDoseReminders = false,
    this.missedDoseDelayMinutes = 15,
    this.maxMissedReminders = 2,
  });
}
