// notification_service.dart – Android-only, rolling-window, 2 h timeout
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
// your existing log feature
import '../log/service.dart';
import '../log/log_model.dart' as feature;

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
      await _initialiseChannels();
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: _onAction,
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
        final candidate = DateTime(now.year, now.month, now.day + d, tod.hour, tod.minute);
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
        schedule: NotificationCalendar.fromDate(
          date: doseTime,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );
      return created;
    } catch (e) {
      debugPrint('❌ scheduleSimpleReminder exception: $e');
      return false;
    }
  }

  /* ================================================================
                        ACTION HANDLER  (3 cases)
     ================================================================ */

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

    // 3. dismissed (swipe away or 2-hour timeout) → auto-missed
    if (action.buttonKeyPressed == null) {
      await _logService.saveLog(
        scheduleId: payload['scheduleId']!,
        status: feature.LogStatus.missed,
        date: date,
      );
      await _showToast('⏰ $medicineName auto-marked missed (2 h)');
      await _rescheduleNext(medicineId);
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
    final remainingDays = (plan['durationDays'] as int) - DateTime.now().difference(startDate).inDays;

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