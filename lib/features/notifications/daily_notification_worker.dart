// daily_notification_worker.dart
import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // For TimeOfDay

// --- ADJUST THESE IMPORT PATHS TO MATCH YOUR PROJECT STRUCTURE ---
import '/data/models/med.dart';
// import 'package:medicare_app/data/models/log.dart';
import 'service.dart';
import 'notifications_model.dart';
import '/data/hive_init.dart';

// --- 1. Define the task name (keep consistent) ---
const String dailyNotificationTask = "com.yourapp.daily_notification_task";

// --- 2. The top-level callback dispatcher (REQUIRED annotation) ---
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("Background Task '$task' started");
    
    // Modern switch expression (Dart 3.0+) or traditional switch
    switch (task) {
      case dailyNotificationTask:
        try {
          // --- CRUCIAL: Re-initialize Hive environment for the background isolate ---
          await initHive();
          debugPrint("Hive initialized in background isolate.");

          // --- Run the daily scheduling logic ---
          await scheduleDailyNotifications();

          debugPrint("Daily notification scheduling completed successfully.");
          return Future.value(true); // Explicit Future return for modern WorkManager
        } catch (e, stack) {
          debugPrint("Error in daily notification scheduling background task: $e\nStack Trace: $stack");
          return Future.value(false);
        }
      default:
        debugPrint("Unknown task: $task");
        return Future.value(false);
    }
  });
}

// --- 3. The core logic function ---
/// Schedules notifications for all active medications for the upcoming day.
Future<void> scheduleDailyNotifications() async {
  debugPrint("Starting daily notification scheduling logic...");

  try {
    // --- Get references to boxes (should be open from initHive) ---
    final medsBox = Hive.box<Med>('meds');

    // --- Get the NotificationService instance ---
    final notificationService = NotificationService.instance;
    
    // Initialize NotificationService in background context
    final initResult = await notificationService.initialize();
    switch (initResult) {
      case NotificationSuccess():
        debugPrint("NotificationService initialized successfully in background");
      case NotificationError(message: final msg):
        debugPrint("Failed to initialize NotificationService: $msg");
        return; // Exit early if initialization fails
    }

    // --- Calculate the target date (tomorrow) ---
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowString = tomorrow.toIso8601String().split('T')[0];
    debugPrint("Scheduling notifications for: $tomorrowString");

    // --- Cancel all existing scheduled notifications (cleanup) ---
    final cancelResult = await notificationService.cancelAllNotifications();
    switch (cancelResult) {
      case NotificationSuccess():
        debugPrint("Cancelled all existing notifications.");
      case NotificationError(message: final msg):
        debugPrint("Warning: Failed to cancel existing notifications: $msg");
        // Continue anyway
    }

    // --- Iterate through all medications ---
    int totalNotificationsScheduled = 0;
    final activeMedications = medsBox.values.where((med) => _isMedicationActiveOnDate(med, tomorrow));
    
    for (final Med medication in activeMedications) {
      debugPrint("Processing active medication: ${medication.name} (${medication.id})");

      // --- For each schedule time, create a ScheduleNotificationModel ---
      for (int i = 0; i < medication.scheduleTimes.length; i++) {
        final TimeOfDay timeOfDay = medication.scheduleTimes[i];

        // --- Create a ScheduleNotificationModel for this specific time tomorrow ---
        final scheduleModel = ScheduleNotificationModel(
          scheduleId: '${medication.id}_$i',
          medicineId: medication.id,
          medicineName: medication.name,
          dosage: medication.dosage,
          time: _formatTimeOfDay(timeOfDay),
          startDate: tomorrow,
          endDate: tomorrow,
        );

        // --- Schedule this specific notification ---
        final scheduleResult = await notificationService.scheduleNotificationsForSchedule(scheduleModel);
        
        switch (scheduleResult) {
          case NotificationSuccess():
            totalNotificationsScheduled++;
            debugPrint("  ✓ Scheduled notification for ${medication.name} at ${scheduleModel.time} (Schedule ID: ${scheduleModel.scheduleId})");
          case NotificationError(message: final msg):
            debugPrint("  ✗ Failed to schedule notification for ${medication.name}: $msg");
        }
      }
    }

    debugPrint("Daily scheduling complete. Total notifications scheduled: $totalNotificationsScheduled");

  } catch (e, stack) {
    debugPrint("Error during daily notification scheduling logic: $e\nStack Trace: $stack");
    // Don't rethrow in WorkManager context - let it handle the boolean return
  }
}

// --- 4. Helper functions ---

/// Helper method to check if a medication is active on a specific date.
bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
  final startDate = DateTime(med.startAt.year, med.startAt.month, med.startAt.day);
  
  // If the medication starts after the target date, it's not active
  if (startDate.isAfter(targetDate)) {
    return false;
  }
  
  // If the medication has an end date and it's before the target date, it's not active
  if (med.endAt != null) {
    final endDate = DateTime(med.endAt!.year, med.endAt!.month, med.endAt!.day);
    if (endDate.isBefore(targetDate)) {
      return false;
    }
  }
  
  return true;
}

/// Helper method to format TimeOfDay to string (HH:MM format)
String _formatTimeOfDay(TimeOfDay timeOfDay) {
  return '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
}

/// Helper method to calculate initial delay for scheduling
Duration _calculateInitialDelay() {
  final now = DateTime.now();
  var targetTime = DateTime(now.year, now.month, now.day, 23, 30); // 11:30 PM today
  
  // If it's already past 11:30 PM today, schedule for tomorrow
  if (targetTime.isBefore(now)) {
    targetTime = targetTime.add(const Duration(days: 1));
  }
  
  return targetTime.difference(now);
}

// --- 5. Function to initialize and register the Work Manager task ---
/// Call this function from your main.dart during app initialization.
Future<void> initializeWorkManager() async {
  try {
    // --- Initialize the Workmanager plugin ---
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode, // Use Flutter's debug mode flag
    );
    debugPrint("Workmanager plugin initialized.");

    // --- Cancel any existing tasks first (cleanup) ---
    await Workmanager().cancelAll();
    debugPrint("Cancelled all existing WorkManager tasks.");

    // --- Register the periodic task with modern API ---
    await Workmanager().registerPeriodicTask(
      "daily_notification_task_1", // Unique task ID
      dailyNotificationTask, // Task name
      frequency: const Duration(hours: 24), // Run every 24 hours
      initialDelay: _calculateInitialDelay(), // Calculated delay
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      inputData: const <String, dynamic>{}, // Modern const Map syntax
      backoffPolicy: BackoffPolicy.exponential, // Modern backoff policy
      backoffPolicyDelay: const Duration(minutes: 15), // Backoff delay
      existingWorkPolicy: ExistingWorkPolicy.replace, // Replace existing work
    );
    
    debugPrint("Workmanager periodic task '$dailyNotificationTask' registered successfully.");
    debugPrint("Initial delay: ${_calculateInitialDelay().inHours} hours, ${_calculateInitialDelay().inMinutes % 60} minutes");
    
  } catch (e, stack) {
    debugPrint("Error initializing Workmanager: $e\nStack Trace: $stack");
    rethrow; // Rethrow for proper error handling in main.dart
  }
}

// --- 6. Additional utility functions for better WorkManager management ---

/// Cancel the daily notification task
Future<void> cancelDailyNotificationTask() async {
  try {
    await Workmanager().cancelByUniqueName("daily_notification_task_1");
    debugPrint("Daily notification task cancelled successfully.");
  } catch (e) {
    debugPrint("Error cancelling daily notification task: $e");
  }
}

/// Check if the daily notification task is registered
Future<bool> isDailyNotificationTaskRegistered() async {
  try {
    // Note: WorkManager doesn't provide a direct way to check if a specific task is registered
    // This is a limitation of the plugin, so we'll use SharedPreferences or similar for tracking if needed
    return true; // Placeholder - implement tracking logic if needed
  } catch (e) {
    debugPrint("Error checking daily notification task status: $e");
    return false;
  }
}

/// Force run the daily notification task (for testing)
Future<void> runDailyNotificationTaskNow() async {
  try {
    await Workmanager().registerOneOffTask(
      "daily_notification_test_${DateTime.now().millisecondsSinceEpoch}",
      dailyNotificationTask,
      initialDelay: const Duration(seconds: 5), // Run after 5 seconds
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
    debugPrint("Daily notification task scheduled to run immediately for testing.");
  } catch (e) {
    debugPrint("Error scheduling immediate daily notification task: $e");
  }
}