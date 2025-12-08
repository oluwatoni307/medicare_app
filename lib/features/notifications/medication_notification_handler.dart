import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../log/service.dart';
import '../log/log_model.dart' as feature;

class MedicationNotificationHandler {
  MedicationNotificationHandler._();
  static final MedicationNotificationHandler instance =
      MedicationNotificationHandler._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final LogService _logService = LogService();

  bool _initialized = false;

  /// Initialize notification handler
  Future<void> init() async {
    if (_initialized) return;

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'medication_reminders',
      'Medication Reminders',
      description: 'Notifications for medication reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Set up Firebase message handlers
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification opened app from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationData(message.data);
      }
    });

    // Handle notification opened app from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationData(message.data);
    });

    await _logService.init();
    _initialized = true;

    debugPrint("✅ Medication Notification Handler initialized");
  }

  /// Handle foreground messages
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint("📱 Foreground message received: ${message.messageId}");

    if (message.data['notification_type'] == 'medication_reminder') {
      await showNotificationWithActions(
        title: message.notification?.title ?? 'Medication Reminder',
        body: message.notification?.body ?? 'Time to take your medication',
        medicineId: message.data['medicine_id'],
        scheduleId: message.data['schedule_id'],
        reminderTime: message.data['reminder_time'],
      );
    }
  }

  /// Show notification with "Taken" and "Missed" action buttons
  Future<void> showNotificationWithActions({
    required String title,
    required String body,
    String? medicineId,
    String? scheduleId,
    String? reminderTime,
  }) async {
    // Create unique notification ID based on schedule
    final notificationId =
        scheduleId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.toInt();

    final androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      'Medication Reminders',
      channelDescription: 'Notifications for medication reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: [
        AndroidNotificationAction(
          'taken_$notificationId',
          '✓ Taken',
          showsUserInterface: false, // Don't open the app
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'missed_$notificationId',
          '✗ Missed',
          showsUserInterface: false, // Don't open the app
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: '$medicineId|$scheduleId|$reminderTime',
    );

    debugPrint("🔔 Notification shown with actions for $scheduleId");
  }

  /// Handle notification tapped or action button pressed
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    debugPrint("👆 Notification tapped: ${response.actionId}");

    final payload = response.payload;
    if (payload == null) return;

    // Parse payload: medicineId|scheduleId|reminderTime
    final parts = payload.split('|');
    if (parts.length < 2) return;

    final medicineId = parts[0];
    final scheduleId = parts[1];

    // Check if an action button was pressed
    if (response.actionId != null) {
      if (response.actionId!.startsWith('taken_')) {
        await _markAsTaken(scheduleId);
      } else if (response.actionId!.startsWith('missed_')) {
        await _markAsMissed(scheduleId);
      }
    } else {
      // Notification body was tapped - open app to medication details
      debugPrint("📱 Opening app for medicine: $medicineId");
      // Navigate to your medication detail screen here
      // Example: Get.to(() => MedicationDetailScreen(medicineId: medicineId));
    }
  }

  /// Handle notification data when app is opened from notification
  void _handleNotificationData(Map<String, dynamic> data) {
    if (data['notification_type'] == 'medication_reminder') {
      final medicineId = data['medicine_id'];
      debugPrint("📱 App opened from notification for medicine: $medicineId");
      // Navigate to your medication detail screen here
      // Example: Get.to(() => MedicationDetailScreen(medicineId: medicineId));
    }
  }

  /// Mark medication as taken
  Future<void> _markAsTaken(String scheduleId) async {
    try {
      debugPrint("✅ Marking as taken: $scheduleId");

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Check if log already exists
      final existingLog = await _logService.getLog(
        scheduleId: scheduleId,
        date: today,
      );

      if (existingLog != null) {
        // Update existing log
        await _logService.updateLog(
          logId: existingLog.id,
          status: feature.LogStatus.taken,
        );
      } else {
        // Create new log
        await _logService.createLog(
          scheduleId: scheduleId,
          date: today,
          status: feature.LogStatus.taken,
        );
      }

      // Show confirmation
      _showToast("✓ Marked as taken");

      debugPrint("✅ Successfully marked as taken");
    } catch (e) {
      debugPrint("❌ Error marking as taken: $e");
      _showToast("Failed to mark as taken");
    }
  }

  /// Mark medication as missed
  Future<void> _markAsMissed(String scheduleId) async {
    try {
      debugPrint("⚠️ Marking as missed: $scheduleId");

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Check if log already exists
      final existingLog = await _logService.getLog(
        scheduleId: scheduleId,
        date: today,
      );

      if (existingLog != null) {
        // Update existing log
        await _logService.updateLog(
          logId: existingLog.id,
          status: feature.LogStatus.missed,
        );
      } else {
        // Create new log
        await _logService.createLog(
          scheduleId: scheduleId,
          date: today,
          status: feature.LogStatus.missed,
        );
      }

      // Show confirmation
      _showToast("✗ Marked as missed");

      debugPrint("✅ Successfully marked as missed");
    } catch (e) {
      debugPrint("❌ Error marking as missed: $e");
      _showToast("Failed to mark as missed");
    }
  }

  /// Show a simple toast message
  void _showToast(String message) {
    // You can use a package like 'fluttertoast' or show a SnackBar
    // For now, just printing
    debugPrint("🍞 Toast: $message");

    // If you have a BuildContext available, you can show a SnackBar:
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    // );
  }
}
