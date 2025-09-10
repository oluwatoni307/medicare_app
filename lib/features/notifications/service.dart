// notification_service.dart – Android-only, rolling-window, 2 h timeout
import 'dart:convert';
import 'dart:typed_data';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
// your existing log feature
import '../log/service.dart';
import '../log/log_model.dart' as feature;

/// Top-level background handler required for delivered actions
@pragma('vm:entry-point')
Future<void> onActionReceivedBackground(ReceivedAction action) async {
  // forward to singleton
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
      
      // Initialize AwesomeNotifications first with proper channel config
      await _initializeAwesomeNotifications();
      
      // Register listeners for background actions
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

  /// Initialize AwesomeNotifications with proper channel configuration
  Future<void> _initializeAwesomeNotifications() async {
    await AwesomeNotifications().initialize(
      null, // null uses default app icon
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
      debug: true, // Enable debug mode to see what's happening
    );
    _channelInitialized = true;
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
      // Create notification with properly configured action buttons
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
          autoDismissible: false, // Changed: Don't auto-dismiss to ensure buttons work
          showWhen: true,
          displayOnBackground: true,
          displayOnForeground: true,
          notificationLayout: NotificationLayout.BigText, // Changed: Use BigText for better button display
          timeoutAfter: const Duration(hours: 2),
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'TAKEN',
            label: 'Taken',
            actionType: ActionType.KeepOnTop, // Changed: KeepOnTop ensures button works in background
            color: Colors.green,
            autoDismissible: true,
          ),
          NotificationActionButton(
            key: 'MISSED',
            label: 'Missed',
            actionType: ActionType.KeepOnTop, // Changed: KeepOnTop ensures button works in background
            color: Colors.orange,
            autoDismissible: true,
          ),
        ],
        schedule: NotificationCalendar.fromDate(
          date: doseTime,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );

      // Schedule follow-up notification
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
            autoDismissible: false, // Changed: Don't auto-dismiss
            showWhen: true,
            displayOnBackground: true,
            displayOnForeground: true,
            notificationLayout: NotificationLayout.BigText, // Changed: Use BigText
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'TAKEN',
              label: 'Mark as Taken',
              actionType: ActionType.KeepOnTop, // Changed: KeepOnTop
              color: Colors.green,
              autoDismissible: true,
            ),
            NotificationActionButton(
              key: 'MISSED',
              label: 'Confirm Missed',
              actionType: ActionType.KeepOnTop, // Changed: KeepOnTop
              color: Colors.orange,
              autoDismissible: true,
            ),
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
                        ACTION HANDLER
     ================================================================ */

  Future<void> _onAction(ReceivedAction action) async {
    // Initialize services if needed (when called from background)
    if (!_logService.isInitialized) {
      await _logService.init();
    }
    
    final payload = action.payload;
    if (payload == null) return;

    final medicineId = payload['medicineId'];
    if (medicineId == null) return;
    
    final date = payload['date'] ?? DateTime.now().toIso8601String().split('T').first;
    final medicineName = payload['medicineName'] ?? 'Medicine';
    final scheduleId = payload['scheduleId'] ?? '';

    debugPrint('🔔 Action received: ${action.buttonKeyPressed} for $medicineName');

    // Handle TAKEN button
    if (action.buttonKeyPressed == 'TAKEN') {
      await _logService.saveLog(
        scheduleId: scheduleId,
        status: feature.LogStatus.taken,
        date: date,
      );
      
      // Cancel the follow-up "missed" notification if it exists
      final followId = _generateStableId('${scheduleId}_auto_miss', 
        DateTime.parse(date).add(const Duration(hours: 2)));
      await AwesomeNotifications().cancel(followId);
      
      await _showToast('✅ $medicineName logged as taken');
      await _rescheduleNext(medicineId);
      return;
    }

    // Handle MISSED button
    if (action.buttonKeyPressed == 'MISSED') {
      await _logService.saveLog(
        scheduleId: scheduleId,
        status: feature.LogStatus.missed,
        date: date,
      );
      
      // Cancel the follow-up notification if it exists
      final followId = _generateStableId('${scheduleId}_auto_miss', 
        DateTime.parse(date).add(const Duration(hours: 2)));
      await AwesomeNotifications().cancel(followId);
      
      await _showToast('⚠️ $medicineName marked as missed');
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
        notificationLayout: NotificationLayout.Default,
        timeoutAfter: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> sendTestNotification() async {
    // Send immediate test notification with action buttons
    final id = DateTime.now().millisecondsSinceEpoch;
    return await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: _medChannel,
        title: '💊 Test Medicine',
        body: 'This is a test notification. Try the action buttons!',
        summary: 'Test Notification',
        wakeUpScreen: true,
        category: NotificationCategory.Alarm,
        payload: {
          'medicineId': 'test',
          'scheduleId': 'test_schedule',
          'date': DateTime.now().toIso8601String().split('T').first,
          'medicineName': 'Test Medicine',
          'dosage': '1 tablet',
        },
        autoDismissible: false,
        showWhen: true,
        displayOnBackground: true,
        displayOnForeground: true,
        notificationLayout: NotificationLayout.BigText,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'TAKEN',
          label: 'Taken',
          actionType: ActionType.KeepOnTop,
          color: Colors.green,
          autoDismissible: true,
        ),
        NotificationActionButton(
          key: 'MISSED',
          label: 'Missed',
          actionType: ActionType.KeepOnTop,
          color: Colors.orange,
          autoDismissible: true,
        ),
      ],
    );
  }

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
        ADDITIONAL METHODS
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
    await _initializeAwesomeNotifications();
  }

  Future<void> _initialiseChannels() => _ensureChannelExists();
}

/* ================================================================
                      SETTINGS MODEL
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

// Extension to check if LogService is initialized
extension LogServiceExtension on LogService {
  bool get isInitialized => true; // Implement based on your LogService
}