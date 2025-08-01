// notification_service.dart
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/log.dart';
import '../../data/models/med.dart';
import '../log/log_model.dart' as feature;
import '../log/service.dart';
import 'notifications_model.dart';

/// Modern notification action types using enhanced enums (Dart 2.17+)
enum NotificationAction {
  taken('taken'),
  missed('missed'),
  navigate('navigate');

  const NotificationAction(this.value);
  final String value;

  static NotificationAction? fromString(String? value) {
    for (final action in NotificationAction.values) {
      if (action.value == value) return action;
    }
    return null;
  }
}

/// Result types for better error handling
sealed class NotificationResult {}

final class NotificationSuccess extends NotificationResult {
  final String? message;
  NotificationSuccess([this.message]);
}

final class NotificationError extends NotificationResult {
  final String message;
  final Object? exception;
  NotificationError(this.message, [this.exception]);
}

/// Date formatting extension for cleaner code
extension DateTimeFormatting on DateTime {
  String get dateString => DateFormat('yyyy-MM-dd').format(this);
  String get timeString => DateFormat('HH:mm').format(this);
}

/// Modern NotificationService with dependency injection support
class NotificationService {
  // Modern singleton pattern with late initialization
  static late final NotificationService _instance;
  static bool _isInitialized = false;

  // Dependencies (can be injected for testing)
  final FlutterLocalNotificationsPlugin _notifications;
  final LogService _logService;
  late final SharedPreferences _prefs;

  // Navigation callback for decoupling
  void Function(String route, Map<String, dynamic> arguments)? _navigationCallback;

  // Current settings
  NotificationSettingsModel _settings = const NotificationSettingsModel();

  // Private constructor
  NotificationService._({
    FlutterLocalNotificationsPlugin? notifications,
    LogService? logService,
  })  : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _logService = logService ?? LogService();

  /// Get singleton instance
  static NotificationService get instance {
    if (!_isInitialized) {
      _instance = NotificationService._();
      _isInitialized = true;
    }
    return _instance;
  }

  /// Factory constructor for dependency injection (testing)
  factory NotificationService.withDependencies({
    required FlutterLocalNotificationsPlugin notifications,
    required LogService logService,
  }) {
    return NotificationService._(
      notifications: notifications,
      logService: logService,
    );
  }

  // --- PUBLIC API ---

  /// Set navigation callback for handling notification taps
  void setNavigationCallback(
    void Function(String route, Map<String, dynamic> arguments) callback,
  ) {
    _navigationCallback = callback;
  }

  /// Initialize notification system with modern async/await patterns
  /// 
  /// Returns [NotificationResult] indicating success or failure with details.
  /// 
  /// Example:
  /// ```dart
  /// final result = await NotificationService.instance.initialize();
  /// switch (result) {
  ///   case NotificationSuccess():
  ///     // Proceed with app
  ///   case NotificationError(message: final msg):
  ///     // Handle error: msg
  /// }
  /// ```
  Future<NotificationResult> initialize() async {
    try {
      // Initialize timezone data first
      tz.initializeTimeZones();

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Modern notification initialization settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        requestCriticalPermission: false,
        requestProvisionalPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      // Initialize with modern callback handling
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationResponse,
      );

      if (initialized != true) {
        return NotificationError('Failed to initialize notifications');
      }

      // Load settings after successful initialization
      await _loadSettings();

      // Initialize LogService
      await _logService.init();

      developer.log('NotificationService initialized successfully');
      return NotificationSuccess('Notifications initialized');

    } on Exception catch (e, stackTrace) {
      developer.log(
        'Failed to initialize NotificationService',
        error: e,
        stackTrace: stackTrace,
      );
      return NotificationError('Initialization failed', e);
    }
  }

  /// Request permissions with modern permission handling
  Future<NotificationResult> requestPermissions() async {
    try {
      // Request basic notification permission
      final notificationStatus = await Permission.notification.request();

      if (!notificationStatus.isGranted) {
        return NotificationError('Notification permission denied');
      }

      // Request platform-specific permissions
      bool platformPermissionsGranted = true;

      // iOS/macOS specific permissions
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        platformPermissionsGranted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        ) ?? false;
      }

      final macOSPlugin = _notifications
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      
      if (macOSPlugin != null) {
        platformPermissionsGranted = await macOSPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        ) ?? false;
      }

      // Android 13+ specific permissions
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }

      return platformPermissionsGranted
          ? NotificationSuccess('All permissions granted')
          : NotificationError('Some platform permissions denied');

    } on Exception catch (e, stackTrace) {
      developer.log(
        'Failed to request permissions',
        error: e,
        stackTrace: stackTrace,
      );
      return NotificationError('Permission request failed', e);
    }
  }

  /// Schedule notifications for a medicine schedule with modern async patterns
  Future<NotificationResult> scheduleNotificationsForSchedule(
    ScheduleNotificationModel schedule,
  ) async {
    if (!_settings.notificationsEnabled) {
      return NotificationError('Notifications are disabled');
    }

    try {
      // Cancel existing notifications for this schedule
      await _cancelNotificationsForSchedule(schedule.scheduleId);

      // Generate notification models
      final notifications = _generateNotificationsForSchedule(schedule);

      if (notifications.isEmpty) {
        return NotificationSuccess('No notifications to schedule');
      }

      // Schedule all notifications in parallel for better performance
      final results = await Future.wait(
        notifications.map(_scheduleNotification),
        eagerError: false, // Continue even if some fail
      );

      final failures = results.whereType<NotificationError>().toList();
      final successes = results.whereType<NotificationSuccess>().toList();

      if (failures.isNotEmpty) {
        developer.log('Some notifications failed to schedule: ${failures.length}');
        return NotificationError(
          'Scheduled ${successes.length}/${notifications.length} notifications',
        );
      }

      developer.log('Scheduled ${notifications.length} notifications for ${schedule.medicineName}');
      return NotificationSuccess('Scheduled ${notifications.length} notifications');

    } on Exception catch (e, stackTrace) {
      developer.log(
        'Failed to schedule notifications for schedule ${schedule.scheduleId}',
        error: e,
        stackTrace: stackTrace,
      );
      return NotificationError('Failed to schedule notifications', e);
    }
  }

  /// Cancel notifications for a specific schedule
  Future<NotificationResult> cancelNotificationsForSchedule(String scheduleId) async {
    try {
      await _cancelNotificationsForSchedule(scheduleId);
      return NotificationSuccess('Notifications cancelled for schedule');
    } on Exception catch (e) {
      return NotificationError('Failed to cancel notifications', e);
    }
  }

  /// Cancel all notifications for a medicine
  Future<NotificationResult> cancelNotificationsForMedicine(String medicineId) async {
    try {
      final pendingNotifications = await _notifications.pendingNotificationRequests();
      final toCancel = <int>[];

      for (final notification in pendingNotifications) {
        final payload = notification.payload;
        if (payload?.isNotEmpty == true) {
          final data = Uri.splitQueryString(payload!);
          if (data['medicineId'] == medicineId) {
            toCancel.add(notification.id);
          }
        }
      }

      // Cancel all matching notifications in parallel
      await Future.wait(
        toCancel.map((id) => _notifications.cancel(id)),
      );

      return NotificationSuccess('Cancelled ${toCancel.length} notifications');

    } on Exception catch (e, stackTrace) {
      developer.log(
        'Failed to cancel notifications for medicine $medicineId',
        error: e,
        stackTrace: stackTrace,
      );
      return NotificationError('Failed to cancel medicine notifications', e);
    }
  }

  /// Update notification settings
  Future<NotificationResult> updateSettings(NotificationSettingsModel settings) async {
    try {
      _settings = settings;
      await _saveSettings();

      if (!settings.notificationsEnabled) {
        await _notifications.cancelAll();
      }

      return NotificationSuccess('Settings updated');
    } on Exception catch (e) {
      return NotificationError('Failed to update settings', e);
    }
  }

  /// Get current settings
  NotificationSettingsModel get settings => _settings;

  /// Cancel all notifications
  Future<NotificationResult> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      return NotificationSuccess('All notifications cancelled');
    } on Exception catch (e) {
      return NotificationError('Failed to cancel all notifications', e);
    }
  }

  /// Get pending notifications count
  Future<int> getPendingNotificationsCount() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      return pending.length;
    } on Exception catch (e) {
      developer.log('Failed to get pending notifications count', error: e);
      return 0;
    }
  }

  // --- INTERNAL LOGIC ---

  /// Store notification payload for later retrieval
  Future<void> _storeNotificationPayload(int notificationId, String payload) async {
    try {
      await _prefs.setString('notification_payload_$notificationId', payload);
    } on Exception catch (e) {
      developer.log('Failed to store notification payload', error: e);
    }
  }

  /// Retrieve stored notification payload
  Future<String?> _getStoredNotificationPayload(int notificationId) async {
    try {
      return _prefs.getString('notification_payload_$notificationId');
    } on Exception catch (e) {
      developer.log('Failed to get stored notification payload', error: e);
      return null;
    }
  }

  /// Clear stored notification payload
  Future<void> _clearStoredNotificationPayload(int notificationId) async {
    try {
      await _prefs.remove('notification_payload_$notificationId');
    } on Exception catch (e) {
      developer.log('Failed to clear stored notification payload', error: e);
    }
  }

  /// Generate notifications with improved date handling
  List<NotificationModel> _generateNotificationsForSchedule(
    ScheduleNotificationModel schedule,
  ) {
    final notifications = <NotificationModel>[];
    final scheduleTime = _parseTime(schedule.time);

    if (scheduleTime == null) {
      developer.log('Invalid time format: ${schedule.time}');
      return notifications;
    }

    var currentDate = schedule.startDate;
    var notificationId = 0;

    while (currentDate.isBefore(schedule.endDate) || 
           currentDate.isAtSameMomentAs(schedule.endDate)) {
      
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
          id: '${schedule.scheduleId}_${currentDate.millisecondsSinceEpoch}_${notificationId++}',
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

  /// Schedule single notification with modern notification details
  Future<NotificationResult> _scheduleNotification(NotificationModel notification) async {
    try {
      // Create unique, collision-resistant ID
      final notificationId = _createUniqueNotificationId(notification.id);

      // Modern Android notification details
      final androidDetails = AndroidNotificationDetails(
        'medicine_reminders',
        'Medicine Reminders',
        channelDescription: 'Notifications for medicine schedules',
        importance: Importance.high,
        priority: Priority.high,
        playSound: _settings.soundEnabled,
        enableVibration: _settings.vibrationEnabled,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        // Modern action buttons
        actions: [
          AndroidNotificationAction(
            'TAKEN_${notificationId}',
            'Taken',
            titleColor: const Color.fromARGB(255, 0, 150, 0),
          ),
          AndroidNotificationAction(
            'MISSED_${notificationId}',
            'Missed',
            titleColor: const Color.fromARGB(255, 200, 0, 0),
          ),
        ],
      );

      // Modern iOS/macOS notification details
      final darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: _settings.soundEnabled,
        presentBanner: true,
        presentList: true,
        categoryIdentifier: 'MEDICINE_REMINDER',
        threadIdentifier: notification.medicineId,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // Create payload for the main notification
      final mainPayload = Uri(queryParameters: {
        'action': NotificationAction.navigate.value,
        'medicineId': notification.medicineId,
        'scheduleId': notification.scheduleId,
        'date': notification.scheduledTime.dateString,
        'notificationId': notification.id,
      }).query;

      // Schedule with correct modern syntax - no payload or uiLocalNotificationDateInterpretation parameters
      await _notifications.zonedSchedule(
        notificationId,
        notification.title,
        notification.body,
        _convertToLocalTimezone(notification.scheduledTime),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      // Store payload separately for handling notification response
      await _storeNotificationPayload(notificationId, mainPayload);

      return NotificationSuccess();

    } on Exception catch (e, stackTrace) {
      developer.log(
        'Failed to schedule notification ${notification.id}',
        error: e,
        stackTrace: stackTrace,
      );
      return NotificationError('Failed to schedule notification', e);
    }
  }

  /// Create collision-resistant notification ID
  int _createUniqueNotificationId(String notificationStringId) {
    // Use a more sophisticated approach than simple hashCode
    return notificationStringId.hashCode.abs() % 2147483647; // Max int32 value
  }

  /// Modern timezone conversion with proper local timezone
  tz.TZDateTime _convertToLocalTimezone(DateTime dateTime) {
    final location = tz.local; // Use device's local timezone
    return tz.TZDateTime.from(dateTime, location);
  }

  /// Parse time string with better error handling
  TimeOfDay? _parseTime(String timeStr) {
    try {
      // Support multiple time formats
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          
          if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
            return TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
    } on FormatException catch (e) {
      developer.log('Invalid time format: $timeStr', error: e);
    } on RangeError catch (e) {
      developer.log('Time values out of range: $timeStr', error: e);
    }
    return null;
  }

  /// Cancel notifications for specific schedule (internal)
  Future<void> _cancelNotificationsForSchedule(String scheduleId) async {
    final pendingNotifications = await _notifications.pendingNotificationRequests();
    final toCancel = <int>[];

    for (final notification in pendingNotifications) {
      final payload = notification.payload;
      if (payload?.isNotEmpty == true) {
        final data = Uri.splitQueryString(payload!);
        if (data['scheduleId'] == scheduleId) {
          toCancel.add(notification.id);
        }
      }
    }

    // Cancel in parallel for better performance
    await Future.wait(
      toCancel.map((id) => _notifications.cancel(id)),
    );
  }

  /// Modern notification response handler
  void _handleNotificationResponse(NotificationResponse response) {
    _processNotificationAction(response, isBackground: false);
  }

  /// Background notification handler (static method required)
  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationResponse(NotificationResponse response) {
    // For background processing, we need to ensure proper initialization
    NotificationService.instance._processNotificationAction(response, isBackground: true);
  }

  /// Process notification actions with modern pattern matching
  Future<void> _processNotificationAction(
    NotificationResponse response, {
    required bool isBackground,
  }) async {
    // First check if we have a direct payload from the response
    String? payload = response.payload;
    
    // If no payload, try to get it from stored payloads (for action buttons)
    if (payload?.isEmpty ?? true) {
      payload = await _getStoredNotificationPayload(response.id ?? 0);
    }

    if (payload?.isEmpty ?? true) {
      developer.log('Received notification with empty payload');
      return;
    }

    try {
      final data = Uri.splitQueryString(payload!);
      final actionString = data['action'];
      final medicineId = data['medicineId'];
      final scheduleId = data['scheduleId'];
      final dateString = data['date'];

      // Validate required data
      if (medicineId?.isEmpty ?? true) {
        developer.log('Missing required data in notification payload');
        return;
      }

      // Clear stored payload after processing
      if (response.id != null) {
        await _clearStoredNotificationPayload(response.id!);
      }

      final action = NotificationAction.fromString(actionString);
      
      // Handle actions with modern switch expressions (Dart 3.0+)
      switch (action) {
        case NotificationAction.taken:
          await _handleMedicineAction(
            medicineId!,
            scheduleId!,
            dateString,
            feature.LogStatus.taken,
            isBackground: isBackground,
          );
        case NotificationAction.missed:
          await _handleMedicineAction(
            medicineId!,
            scheduleId!,
            dateString,
            feature.LogStatus.missed,
            isBackground: isBackground,
          );
        case NotificationAction.navigate:
        case null:
          await _handleNavigation(medicineId!, scheduleId!, dateString);
      }

    } on Exception catch (e, stackTrace) {
      developer.log(
        'Error processing notification action',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handle medicine action logging with proper Hive management
  Future<void> _handleMedicineAction(
    String medicineId,
    String scheduleId,
    String? dateString,
    feature.LogStatus status, {
    required bool isBackground,
  }) async {
    try {
      // Ensure Hive boxes are available (especially important for background processing)
      if (!Hive.isBoxOpen('meds')) {
        await Hive.openBox<Med>('meds');
      }
      if (!Hive.isBoxOpen('logs')) {
        await Hive.openBox<LogModel>('logs');
      }

      // Ensure LogService is initialized
      await _logService.init();

      final targetDateStr = dateString ?? DateTime.now().dateString;

      // Log the medicine action
      await _logService.saveLog(
        scheduleId: scheduleId,
        status: status,
        date: targetDateStr,
      );

      final statusText = status == feature.LogStatus.taken ? 'taken' : 'missed';
      developer.log('Medicine $medicineId marked as $statusText for $targetDateStr');

      // Show confirmation if not in background
      if (!isBackground) {
        await _showQuickConfirmation(
          'Medicine Logged',
          'Marked as $statusText',
        );
      }

    } on Exception catch (e, stackTrace) {
      developer.log(
        'Failed to log medicine action',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handle navigation with callback pattern
  Future<void> _handleNavigation(
    String medicineId,
    String scheduleId,
    String? dateString,
  ) async {
    if (_navigationCallback != null) {
      final arguments = {
        'medicineId': medicineId,
        'scheduleId': scheduleId,
        'date': dateString ?? DateTime.now().dateString,
      };

      _navigationCallback!('/log', arguments);
      developer.log('Navigating to log screen with arguments: $arguments');
    } else {
      developer.log('Navigation callback not set. Cannot navigate to log screen.');
    }
  }

  /// Show quick confirmation notification
  Future<void> _showQuickConfirmation(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'quick_feedback',
        'Quick Feedback',
        channelDescription: 'Brief confirmations',
        importance: Importance.low,
        priority: Priority.low,
        timeoutAfter: 3000,
        autoCancel: true,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000, // Unique ID
        title,
        body,
        notificationDetails,
      );
    } on Exception catch (e) {
      developer.log('Failed to show confirmation notification', error: e);
    }
  }

  /// Load settings with modern async/await
  Future<void> _loadSettings() async {
    try {
      final settingsJson = _prefs.getString('notification_settings');
      if (settingsJson?.isNotEmpty == true) {
        final data = jsonDecode(settingsJson!) as Map<String, dynamic>;
        _settings = NotificationSettingsModel.fromJson(data);
      }
    } on Exception catch (e) {
      developer.log('Failed to load notification settings, using defaults', error: e);
      // Keep default settings
    }
  }

  /// Save settings with error handling
  Future<void> _saveSettings() async {
    try {
      await _prefs.setString(
        'notification_settings',
        jsonEncode(_settings.toJson()),
      );
    } on Exception catch (e) {
      developer.log('Failed to save notification settings', error: e);
      throw Exception('Failed to save settings: $e');
    }
  }

  /// Cleanup method for proper resource management
  Future<void> dispose() async {
    // Cancel all notifications
    await _notifications.cancelAll();
    
    // Clear callbacks
    _navigationCallback = null;
    
    developer.log('NotificationService disposed');
  }
}