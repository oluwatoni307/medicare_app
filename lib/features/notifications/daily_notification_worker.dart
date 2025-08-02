// daily_notification_worker.dart
import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// --- ADJUST THESE IMPORT PATHS TO MATCH YOUR PROJECT STRUCTURE ---
import '/data/models/med.dart';
import '/data/models/log.dart';
import '/data/models/time_of_day_adapter.dart';
import 'service.dart';
import 'notifications_model.dart';

// --- 1. Define the task name (keep consistent) ---
const String dailyNotificationTask = "com.yourapp.daily_notification_task";

// --- 2. The top-level callback dispatcher (REQUIRED annotation) ---
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("Background Task '$task' started at ${DateTime.now()}");
    
    switch (task) {
      case dailyNotificationTask:
        try {
          // --- CRUCIAL: Complete Hive re-initialization for background isolate ---
          await _initializeBackgroundHive();
          debugPrint("Hive initialized in background isolate.");

          // --- Validate permissions before proceeding ---
          if (!await _validateNotificationPermissions()) {
            debugPrint("Notification permissions not granted, skipping scheduling");
            return Future.value(false);
          }

          // --- Run the daily scheduling logic ---
          final success = await _scheduleTodaysNotifications();

          debugPrint("Daily notification scheduling completed. Success: $success");
          return Future.value(success);
          
        } catch (e, stack) {
          debugPrint("Critical error in daily notification background task: $e\nStack: $stack");
          return Future.value(false);
        } finally {
          // --- Ensure cleanup happens regardless of success/failure ---
          await _cleanupBackgroundHive();
        }
        
      default:
        debugPrint("Unknown background task: $task");
        return Future.value(false);
    }
  });
}

// --- 3. Background-specific Hive initialization ---
Future<void> _initializeBackgroundHive() async {
  try {
    // Initialize Hive for background isolate
    await Hive.initFlutter();

    // Check and register adapters only if not already registered
    if (!Hive.isAdapterRegistered(MedAdapter().typeId)) {
      Hive.registerAdapter(MedAdapter());
    }
    if (!Hive.isAdapterRegistered(LogModelAdapter().typeId)) {
      Hive.registerAdapter(LogModelAdapter());
    }
    if (!Hive.isAdapterRegistered(TimeOfDayAdapter().typeId)) {
      Hive.registerAdapter(TimeOfDayAdapter());
    }

    // Open boxes - these will be separate instances from main isolate
    if (!Hive.isBoxOpen('meds')) {
      await Hive.openBox<Med>('meds');
    }
    if (!Hive.isBoxOpen('logs')) {
      await Hive.openBox<LogModel>('logs');
    }

    debugPrint("Background Hive initialization complete");
  } catch (e, stack) {
    debugPrint("Failed to initialize Hive in background: $e\nStack: $stack");
    rethrow;
  }
}

// --- 4. Background Hive cleanup ---
Future<void> _cleanupBackgroundHive() async {
  try {
    // Close boxes to free resources
    if (Hive.isBoxOpen('meds')) {
      await Hive.box<Med>('meds').close();
    }
    if (Hive.isBoxOpen('logs')) {
      await Hive.box<LogModel>('logs').close();
    }
    debugPrint("Background Hive cleanup complete");
  } catch (e) {
    debugPrint("Error during background Hive cleanup: $e");
    // Don't rethrow cleanup errors
  }
}

// --- 5. Permission validation ---
Future<bool> _validateNotificationPermissions() async {
  try {
    final notificationStatus = await Permission.notification.status;
    final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    
    return notificationStatus.isGranted && 
           (exactAlarmStatus.isGranted || exactAlarmStatus.isLimited);
  } catch (e) {
    debugPrint("Error checking permissions: $e");
    return false;
  }
}

// --- 6. Core scheduling logic - UPDATED for "today" instead of "tomorrow" ---
Future<bool> _scheduleTodaysNotifications() async {
  debugPrint("Starting notification scheduling for TODAY...");

  try {
    final medsBox = Hive.box<Med>('meds');
    final notificationService = NotificationService.instance;
    
    // Initialize NotificationService in background context
    final initResult = await notificationService.initialize();
    switch (initResult) {
      case NotificationSuccess():
        debugPrint("NotificationService initialized successfully in background");
      case NotificationError(message: final msg):
        debugPrint("Failed to initialize NotificationService: $msg");
        return false;
    }

    // --- Calculate target date (TODAY, not tomorrow) ---
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayString = today.toIso8601String().split('T')[0];
    debugPrint("Scheduling notifications for TODAY: $todayString");

    // --- Strategic cleanup: Cancel only today's scheduled notifications ---
    await _cancelTodaysNotifications(notificationService, today);

    // --- Get active medications for today ---
    final activeMedications = medsBox.values
        .where((med) => _isMedicationActiveOnDate(med, today))
        .toList();

    debugPrint("Found ${activeMedications.length} active medications for today");

    int totalScheduled = 0;
    int totalFailed = 0;

    // --- Process each medication ---
    for (final Med medication in activeMedications) {
      final result = await _processMedicationScheduling(
        medication, 
        today, 
        notificationService,
      );
      
      if (result.success) {
        totalScheduled += result.scheduledCount;
        debugPrint("✓ ${medication.name}: ${result.scheduledCount} notifications scheduled");
      } else {
        totalFailed++;
        debugPrint("✗ ${medication.name}: scheduling failed - ${result.error}");
      }
    }

    debugPrint("Scheduling complete - Scheduled: $totalScheduled, Failed: $totalFailed medications");
    
    // Consider success if at least some notifications were scheduled or no medications were active
    return totalFailed == 0 || (totalScheduled > 0);

  } catch (e, stack) {
    debugPrint("Error during notification scheduling: $e\nStack: $stack");
    return false;
  }
}

// --- 7. Process individual medication scheduling ---
Future<_SchedulingResult> _processMedicationScheduling(
  Med medication,
  DateTime targetDate,
  NotificationService notificationService,
) async {
  try {
    int scheduledCount = 0;
    final now = DateTime.now();
    
    // Process each schedule time for this medication
    for (int i = 0; i < medication.scheduleTimes.length; i++) {
      final TimeOfDay timeOfDay = medication.scheduleTimes[i];
      
      // Create the full datetime for this notification
      final notificationTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      // UPDATED: Only schedule if the time hasn't passed yet (with 5-minute buffer)
      final bufferTime = now.add(const Duration(minutes: 5));
      if (notificationTime.isBefore(bufferTime)) {
        debugPrint("  Skipping ${medication.name} at ${_formatTimeOfDay(timeOfDay)} - time has passed");
        continue;
      }

      // Create schedule model for this specific time
      final scheduleModel = ScheduleNotificationModel(
        scheduleId: '${medication.id}_${targetDate.millisecondsSinceEpoch}_$i',
        medicineId: medication.id,
        medicineName: medication.name,
        dosage: medication.dosage,
        time: _formatTimeOfDay(timeOfDay),
        startDate: targetDate,
        endDate: targetDate, // Only schedule for today
      );

      // Schedule this notification
      final scheduleResult = await notificationService.scheduleNotificationsForSchedule(scheduleModel);
      
      switch (scheduleResult) {
        case NotificationSuccess():
          scheduledCount++;
          debugPrint("    ✓ Scheduled for ${_formatTimeOfDay(timeOfDay)}");
        case NotificationError(message: final msg):
          debugPrint("    ✗ Failed to schedule for ${_formatTimeOfDay(timeOfDay)}: $msg");
          // Continue with other times even if one fails
      }
    }

    return _SchedulingResult.success(scheduledCount);
    
  } catch (e, stack) {
    debugPrint("Error processing medication ${medication.name}: $e");
    return _SchedulingResult.failure("Exception: $e");
  }
}

// --- 8. Targeted notification cleanup ---
Future<void> _cancelTodaysNotifications(
  NotificationService notificationService,
  DateTime targetDate,
) async {
  try {
    // For daily scheduling, we can cancel all notifications since we're rescheduling everything
    // In a more sophisticated implementation, you might want to cancel only today's notifications
    final cancelResult = await notificationService.cancelAllNotifications();
    switch (cancelResult) {
      case NotificationSuccess():
        debugPrint("Cancelled existing notifications for cleanup");
      case NotificationError(message: final msg):
        debugPrint("Warning: Failed to cancel existing notifications: $msg");
        // Continue anyway - not critical for functionality
    }
  } catch (e) {
    debugPrint("Error during notification cleanup: $e");
    // Non-critical error, continue
  }
}

// --- 9. UPDATED: Medication active date validation ---
bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
  // Compare dates only (ignore time)
  final startDate = DateTime(med.startAt.year, med.startAt.month, med.startAt.day);
  final checkDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
  
  // Medication hasn't started yet
  if (startDate.isAfter(checkDate)) {
    return false;
  }
  
  // Check if medication has ended
  if (med.endAt != null) {
    final endDate = DateTime(med.endAt!.year, med.endAt!.month, med.endAt!.day);
    // Medication has ended (end date is exclusive)
    if (checkDate.isAfter(endDate)) {
      return false;
    }
  }
  
  return true;
}

// --- 10. Helper methods ---
String _formatTimeOfDay(TimeOfDay timeOfDay) {
  return '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
}

// UPDATED: Better initial delay calculation for daily scheduling
Duration _calculateInitialDelay() {
  final now = DateTime.now();
  // Run at 6:00 AM daily (better than 11:30 PM for catching the day's medications)
  var targetTime = DateTime(now.year, now.month, now.day, 6, 0);
  
  // If it's already past 6:00 AM today, schedule for tomorrow at 6:00 AM
  if (targetTime.isBefore(now)) {
    targetTime = targetTime.add(const Duration(days: 1));
  }
  
  return targetTime.difference(now);
}

// --- 11. UPDATED: WorkManager initialization ---
Future<void> initializeWorkManager() async {
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    debugPrint("Workmanager plugin initialized.");

    // Cancel existing tasks
    await Workmanager().cancelAll();
    debugPrint("Cancelled all existing WorkManager tasks.");

    // UPDATED: Better constraints for daily scheduling reliability
    await Workmanager().registerPeriodicTask(
      "daily_notification_task_1",
      dailyNotificationTask,
      frequency: const Duration(hours: 24),
      initialDelay: _calculateInitialDelay(),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false, // Important: don't require high battery
        requiresCharging: false,
        requiresDeviceIdle: false, // Important: can run when device is active
        requiresStorageNotLow: false,
      ),
      inputData: const <String, dynamic>{},
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    
    final delay = _calculateInitialDelay();
    debugPrint("Daily notification task registered successfully.");
    debugPrint("Next run: ${DateTime.now().add(delay)} (in ${delay.inHours}h ${delay.inMinutes % 60}m)");
    
  } catch (e, stack) {
    debugPrint("Error initializing Workmanager: $e\nStack: $stack");
    rethrow;
  }
}

// --- 12. Utility functions (unchanged) ---
Future<void> cancelDailyNotificationTask() async {
  try {
    await Workmanager().cancelByUniqueName("daily_notification_task_1");
    debugPrint("Daily notification task cancelled successfully.");
  } catch (e) {
    debugPrint("Error cancelling daily notification task: $e");
  }
}

Future<bool> isDailyNotificationTaskRegistered() async {
  // WorkManager doesn't provide direct task status checking
  return true; // Placeholder
}

Future<void> runDailyNotificationTaskNow() async {
  try {
    await Workmanager().registerOneOffTask(
      "daily_notification_test_${DateTime.now().millisecondsSinceEpoch}",
      dailyNotificationTask,
      initialDelay: const Duration(seconds: 5),
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

// --- 13. Result classes for better error handling ---
class _SchedulingResult {
  final bool success;
  final int scheduledCount;
  final String? error;

  _SchedulingResult.success(this.scheduledCount) 
    : success = true, error = null;
    
  _SchedulingResult.failure(this.error) 
    : success = false, scheduledCount = 0;
}