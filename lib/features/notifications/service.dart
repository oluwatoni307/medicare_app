// notification_service.dart – Complete fixed version with proper permissions
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:math' as math;
// Import your LogService for direct logging
import '../log/service.dart'; // Adjust path based on your feature structure
import '../log/log_model.dart' as feature;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _medChannel = 'medicine_critical';
  
  final LogService _logService = LogService();
  
  // Track channel initialization state
  bool _channelInitialized = false;

  Future<void> init() async {
    try {
      await _logService.init();
      debugPrint('📱 Initializing notification service...');
      
      await _initializeChannels();
      debugPrint('📱 Channels initialized');
      
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: _onAction,
      );
      debugPrint('📱 Listeners set');
      
      // AUTOMATICALLY REQUEST PERMISSIONS ON INIT
      debugPrint('📱 Requesting permissions...');
      final permissionsGranted = await requestPermissions();
      debugPrint('📱 Permissions granted: $permissionsGranted');
      
      // Run diagnostics after initialization
      await debugNotificationState();
      
    } catch (e) {
      debugPrint('❌ Notification service initialization failed: $e');
      rethrow;
    }
  }

  /* ---------- ANDROID 14+ OPTIMIZED INITIALIZATION ---------- */

  Future<void> _initializeChannels() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: _medChannel,
          channelName: 'Medicine Reminders',
          channelDescription: 'Critical medication dose reminders',
          importance: NotificationImportance.Max,        // MAX for Android 14+ reliability
          defaultColor: Colors.blue,
          ledColor: Colors.white,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]), 
          channelShowBadge: true,
          onlyAlertOnce: false,                          // Allow repeated alerts
          locked: true,                                  // Prevent user from disabling
          defaultRingtoneType: DefaultRingtoneType.Alarm, // Use ALARM for reliability
          enableLights: true,
          criticalAlerts: true,
        ),
      ],
    );
    _channelInitialized = true;
  }

  /* ---------- IMPROVED PERMISSION REQUEST ---------- */

  Future<bool> requestPermissions() async {
    try {
      debugPrint('📱 Checking notification permissions...');
      
      // Basic notification permission
      if (!await AwesomeNotifications().isNotificationAllowed()) {
        debugPrint('📱 Requesting basic notification permission...');
        final granted = await AwesomeNotifications().requestPermissionToSendNotifications();
        debugPrint('📱 Basic notification permission granted: $granted');
        if (!granted) return false;
      } else {
        debugPrint('✅ Basic notification permission already granted');
      }

      // CRITICAL: Exact alarm permission for Android 12+
      debugPrint('📱 Checking exact alarm permission...');
      if (await Permission.scheduleExactAlarm.isDenied) {
        debugPrint('📱 Requesting exact alarm permission...');
        final result = await Permission.scheduleExactAlarm.request();
        debugPrint('📱 Exact alarm permission result: ${result.name}');
        if (!result.isGranted) {
          debugPrint('❌ CRITICAL: Exact alarm permission denied');
          return false;
        }
      } else {
        debugPrint('✅ Exact alarm permission already granted');
      }

      debugPrint('✅ All required permissions granted');
      return true;
    } catch (e) {
      debugPrint('❌ Permission request failed: $e');
      return false;
    }
  }

  /// Request battery optimization exemption (call separately when user enables notifications)
  Future<bool> requestBatteryOptimization() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isDenied) {
        final result = await Permission.ignoreBatteryOptimizations.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('Battery optimization request failed: $e');
      return false;
    }
  }

  /* ---------- RELIABLE SCHEDULING ---------- */

  /// Schedule ONE reliable Android 14+ compatible notification
  Future<bool> scheduleSimpleReminder({
    required String medicineId,
    required String scheduleId,
    required String medicineName,
    required String dosage,
    required DateTime doseTime,
  }) async {
    // CRITICAL: Check permissions first
    if (!await hasPermissions) {
      debugPrint('❌ Missing required permissions for scheduling');
      return false;
    }
    
    // Ensure channel exists before scheduling
    await _ensureChannelExists();
    
    final id = _generateStableId(scheduleId, doseTime);
    
    // Don't schedule past notifications
    if (doseTime.isBefore(DateTime.now().subtract(Duration(minutes: 1)))) {
      debugPrint('⏰ Skipping past notification: $doseTime');
      return false;
    }
    
    try {
      final success = await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: _medChannel,
          title: '💊 $medicineName',
          body: 'Time for your $dosage dose',
          summary: 'Medicine Reminder',
          wakeUpScreen: true,
          fullScreenIntent: true,                        // Android 14+ reliability
          category: NotificationCategory.Alarm,          // High priority category
          payload: {
            'medicineId': medicineId,
            'scheduleId': scheduleId,
            'date': doseTime.toIso8601String().split('T').first,
            'medicineName': medicineName,
            'dosage': dosage,
          },
          autoDismissible: false,                        // Don't auto-dismiss medical alerts
          showWhen: true,
          displayOnBackground: true,
          displayOnForeground: true,
          notificationLayout: NotificationLayout.Default,
          // No timeout for medical notifications
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'LOG_DOSE',
            label: '✅ LOG',
            color: Colors.green,
            autoDismissible: true,
            requireInputText: false,
            actionType: ActionType.Default,
          ),
        ],
        schedule: NotificationCalendar.fromDate(
          date: doseTime,
          preciseAlarm: true,                            // Android 14+ exact timing
          allowWhileIdle: true,                          // Work in Doze mode
        ),
      );

      if (success) {
        debugPrint('✅ Notification scheduled: $scheduleId for $doseTime');
        
        // Verify it was actually scheduled (Android 14+ validation)
        await Future.delayed(Duration(milliseconds: 300));
        final verified = await _verifyScheduled(scheduleId);
        if (!verified) {
          debugPrint('❌ Notification not found in system after scheduling');
          return false;
        }
      } else {
        debugPrint('❌ Failed to schedule notification: $scheduleId');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Exception scheduling notification: $e');
      return false;
    }
  }

  /// Verify notification was actually scheduled (Android 14+ reliability check)
  Future<bool> _verifyScheduled(String scheduleId) async {
    try {
      final scheduled = await AwesomeNotifications().listScheduledNotifications();
      return scheduled.any((n) => n.content?.payload?['scheduleId'] == scheduleId);
    } catch (e) {
      return false;
    }
  }

  /* ---------- BATCH SCHEDULING ---------- */

  Future<void> scheduleAllTreatmentReminders({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> dailyTimes,
    required int durationDays,
  }) async {
    final startDate = DateTime.now();
    int scheduledCount = 0;
    
    // Android limit check
    final currentCount = await this.scheduledCount;
    final maxAllowed = 400; // Conservative limit
    final requestedTotal = durationDays * dailyTimes.length;
    final actualLimit = math.min(requestedTotal, maxAllowed - currentCount);
    
    int processed = 0;
    
    for (int day = 0; day < durationDays && processed < actualLimit; day++) {
      for (int timeIndex = 0; timeIndex < dailyTimes.length && processed < actualLimit; timeIndex++) {
        final time = dailyTimes[timeIndex];
        final doseDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day + day,
          time.hour,
          time.minute,
        );
        
        // Skip past times for today
        if (day == 0 && doseDateTime.isBefore(DateTime.now())) continue;
        
        final scheduleId = '${medicineId}_$timeIndex';
        
        final success = await scheduleSimpleReminder(
          medicineId: medicineId,
          scheduleId: scheduleId,
          medicineName: medicineName,
          dosage: dosage,
          doseTime: doseDateTime,
        );
        
        if (success) scheduledCount++;
        processed++;
        
        // Small delay to avoid overwhelming Android
        if (processed % 15 == 0) {
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
    }
    
    debugPrint('📅 Scheduled $scheduledCount/$processed notifications for $medicineName');
  }

  /// Reschedule all notifications for a medicine (ViewModel compatibility)
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

  /* ---------- ACTION HANDLING ---------- */

Future<void> _onAction(ReceivedAction action) async {
  final payload = action.payload;
  if (payload == null) return;

  final scheduleId = payload['scheduleId'] ?? '';
  final medicineId = payload['medicineId'];
  final date = payload['date'];
  final medicineName = payload['medicineName'] ?? 'Medicine';

  // Skip the dummy confirmation notifications
  if (scheduleId.endsWith('_success')) {
    debugPrint('ℹ️ Ignoring confirmation notification tap');
    await _showConfirmation('$medicineName reminder acknowledged');
    return;
  }

  try {
    if (action.buttonKeyPressed == 'LOG_DOSE') {
      await _logService.saveLog(
        scheduleId: scheduleId,
        status: feature.LogStatus.taken,
        date: date!,
      );
      await _showConfirmation('✅ $medicineName logged');
    }
  } catch (e) {
    debugPrint('⚠️ Could not log dose (probably test/unknown ID): $e');
    // Graceful fallback: just show a toast
    await _showConfirmation('$medicineName reminder dismissed');
  }
}

  /* ---------- PERMISSION CHECKS ---------- */

  /// Check if we have basic required permissions
  Future<bool> get hasPermissions async {
    try {
      final notifications = await AwesomeNotifications().isNotificationAllowed();
      final exactAlarm = await Permission.scheduleExactAlarm.isGranted;
      return notifications && exactAlarm;
    } catch (e) {
      return false;
    }
  }

  /// Check if we have optimal permissions (including battery optimization)
  Future<bool> get hasOptimalAndroidPermissions async {
    try {
      final notifications = await AwesomeNotifications().isNotificationAllowed();
      final exactAlarm = await Permission.scheduleExactAlarm.isGranted;
      final batteryOptimization = await Permission.ignoreBatteryOptimizations.isGranted;
      
      debugPrint('📱 Permissions: Notifications=$notifications, ExactAlarm=$exactAlarm, Battery=$batteryOptimization');
      return notifications && exactAlarm && batteryOptimization;
    } catch (e) {
      return false;
    }
  }

  /// Get permission status map
  Future<Map<String, bool>> get androidPermissionStatus async {
    try {
      return {
        'notifications': await AwesomeNotifications().isNotificationAllowed(),
        'exactAlarm': await Permission.scheduleExactAlarm.isGranted,
        'batteryOptimization': await Permission.ignoreBatteryOptimizations.isGranted,
      };
    } catch (e) {
      return {
        'notifications': false,
        'exactAlarm': false,
        'batteryOptimization': false,
      };
    }
  }

  /* ---------- UTILITY METHODS ---------- */

  Future<void> _showConfirmation(String message) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch,
        channelKey: _medChannel,
        title: '💊 MedTracker',
        body: message,
        autoDismissible: true,
        showWhen: false,
        timeoutAfter: Duration(seconds: 3),
      ),
    );
  }

  Future<bool> sendTest() async {
    return scheduleSimpleReminder(
      medicineId: 'test',
      scheduleId: 'test_schedule',
      medicineName: 'Test Medicine',
      dosage: '1 tablet',
      doseTime: DateTime.now().add(Duration(seconds: 5)),
    );
  }

  Future<bool> sendTestNotification() async {
    return sendTest();
  }

  Future<void> cancelForMedicine(String medicineId) async {
    try {
      final list = await AwesomeNotifications().listScheduledNotifications();
      int canceledCount = 0;
      
      for (final notification in list) {
        if (notification.content?.payload?['medicineId'] == medicineId) {
          await AwesomeNotifications().cancel(notification.content!.id!);
          canceledCount++;
        }
      }
      
      debugPrint('🗑️ Canceled $canceledCount notifications for: $medicineId');
    } catch (e) {
      debugPrint('❌ Error canceling notifications: $e');
    }
  }

  Future<int> get scheduledCount async {
    try {
      final list = await AwesomeNotifications().listScheduledNotifications();
      return list.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await AwesomeNotifications().cancelAll();
      debugPrint('🗑️ All notifications canceled');
    } catch (e) {
      debugPrint('❌ Error canceling all notifications: $e');
    }
  }

  Future<Map<String, int>> getScheduledCountByMedicine() async {
    try {
      final list = await AwesomeNotifications().listScheduledNotifications();
      final counts = <String, int>{};
      
      for (final notification in list) {
        final medicineId = notification.content?.payload?['medicineId'];
        if (medicineId != null) {
          counts[medicineId] = (counts[medicineId] ?? 0) + 1;
        }
      }
      
      return counts;
    } catch (e) {
      return {};
    }
  }

  int _generateStableId(String scheduleId, DateTime dateTime) {
    final idString = '$scheduleId${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}';
    return idString.hashCode.abs();
  }

  /* ---------- ANDROID 14+ RELIABILITY CHECKS ---------- */

  /// Quick system health check
  Future<bool> get isSystemHealthy async {
    try {
      final hasPerms = await hasPermissions;
      final scheduledCountValue = await scheduledCount;
      final hasChannel = await _hasValidChannel();
      
      return hasPerms && scheduledCountValue < 400 && hasChannel;
    } catch (e) {
      return false;
    }
  }

  /// FIXED: Better channel validation that actually checks if channel works
  Future<bool> _hasValidChannel() async {
    try {
      // Try to create a test notification to verify channel works
      final testId = DateTime.now().millisecondsSinceEpoch;
      final testResult = await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: testId,
          channelKey: _medChannel,
          title: 'Channel Test',
          body: 'Testing channel',
          autoDismissible: true,
          showWhen: false,
        ),
      );
      
      // Immediately cancel the test notification
      if (testResult) {
        await AwesomeNotifications().cancel(testId);
      }
      
      return testResult;
    } catch (e) {
      debugPrint('❌ Channel validation failed: $e');
      return false;
    }
  }

  /// Ensure the notification channel exists (idempotent)
  Future<void> _ensureChannelExists() async {
    if (_channelInitialized) return;
    
    try {
      await AwesomeNotifications().setChannel(
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
      );
      _channelInitialized = true;
    } catch (e) {
      debugPrint('❌ Failed to ensure channel exists: $e');
      rethrow;
    }
  }

  /* ---------- DEBUGGING METHODS ---------- */

  /// Comprehensive diagnostic method
  Future<Map<String, dynamic>> getDiagnostics() async {
    final permissions = await androidPermissionStatus;
    final scheduled = await scheduledCount;
    final channelValid = await _hasValidChannel();
    
    return {
      'permissions': permissions,
      'scheduledCount': scheduled,
      'channelValid': channelValid,
      'systemHealthy': await isSystemHealthy,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Debug method to log current notification state
  Future<void> debugNotificationState() async {
    final diagnostics = await getDiagnostics();
    debugPrint('🔍 NOTIFICATION DIAGNOSTICS:');
    debugPrint('   Permissions: ${diagnostics['permissions']}');
    debugPrint('   Scheduled Count: ${diagnostics['scheduledCount']}');
    debugPrint('   Channel Valid: ${diagnostics['channelValid']}');
    debugPrint('   System Healthy: ${diagnostics['systemHealthy']}');
    
    // List current scheduled notifications
    try {
      final scheduled = await AwesomeNotifications().listScheduledNotifications();
      debugPrint('   Scheduled Notifications: ${scheduled.length}');
      for (final notif in scheduled.take(5)) { // Show first 5
        final payload = notif.content?.payload;
        debugPrint('     - ${payload?['medicineName']} at ${notif.schedule?.toString()}');
      }
    } catch (e) {
      debugPrint('   Error listing scheduled: $e');
    }
  }

  /// Show battery optimization guidance for problematic devices
  void showBatteryOptimizationGuidance() {
    debugPrint('''
🔋 BATTERY OPTIMIZATION GUIDANCE:
For reliable notifications:
1. Settings > Apps > [Your App] > Battery
2. Select "Don't optimize" or "No restrictions"
3. Enable "Auto-start" if available

Manufacturer-specific:
- Samsung: Settings > Apps > [App] > Battery > Optimize battery usage > Turn OFF
- Xiaomi: Settings > Apps > [App] > Battery saver > No restrictions  
- Huawei: Settings > Apps > [App] > Battery > App launch > Manage manually
''');
  }

  /* ---------- PUBLIC HELPER METHODS ---------- */
  
  /// Call this method when user first enables notifications or in app settings
  Future<bool> setupNotificationsForUser() async {
    debugPrint('📱 Setting up notifications for user...');
    
    // Request all permissions
    final hasBasicPermissions = await requestPermissions();
    if (!hasBasicPermissions) {
      debugPrint('❌ Basic permissions denied');
      return false;
    }
    
    // Request battery optimization (optional but recommended)
    final hasBatteryOptimization = await requestBatteryOptimization();
    if (!hasBatteryOptimization) {
      debugPrint('⚠️ Battery optimization not granted - notifications may be unreliable');
      showBatteryOptimizationGuidance();
    }
    
    // Test the notification system
    final testResult = await sendTestNotification();
    if (!testResult) {
      debugPrint('❌ Test notification failed');
      return false;
    }
    
    debugPrint('✅ Notification setup completed successfully');
    return true;
  }

  /// Check if system is ready for notifications
  Future<bool> get isReadyForNotifications async {
    final hasPerms = await hasPermissions;
    final isHealthy = await isSystemHealthy;
    return hasPerms && isHealthy;
  }
}

/// Simplified notification settings (backward compatibility)
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