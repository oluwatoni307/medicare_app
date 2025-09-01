import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../notifications/service.dart'; // Your Android-optimized NotificationService
import '/data/models/med.dart'; // Your updated Hive Med model
import '/data/models/log.dart';
import 'AddMedication_model.dart';

class MedicationService {
  late Box<Med> _medsBox;
  late Box<LogModel> _logsBox;

  bool _isInitialized = false;

  // Add this method
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    _medsBox = Hive.box<Med>('meds');
    _logsBox = Hive.box<LogModel>('logs');
    _isInitialized = true;
  }

  /* ---------- CREATE ---------- */

  Future<String> addMedication(MedicationModel med, String userId) async {
    await _ensureInitialized();
    try {
      final hiveMed = Med(
        id: med.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: med.medicationName ?? '',
        dosage: med.dosage ?? '',
        type: med.type ?? '',
        scheduleTimes: med.scheduleTimes ?? [],
        startAt: med.startDate!,
        endAt: _calculateEndDate(med.startDate!, med.duration),
      );

      await _medsBox.add(hiveMed);

      // 🔥 NEW: Schedule confirmation notification using your Android-optimized service
      await NotificationService.instance.scheduleSimpleReminder(
        medicineId: hiveMed.id,
        scheduleId: '${hiveMed.id}_success',
        medicineName: '${hiveMed.name} Added',
        dosage: 'Medication saved - reminders will start soon',
        doseTime: DateTime.now().add(const Duration(minutes: 2)),
      );

      // Schedule all treatment notifications
      await _scheduleNotificationsForMed(hiveMed);

      return hiveMed.id;
    } catch (e) {
      throw Exception('Add medication error: $e');
    }
  }

  /* ---------- READ ---------- */
  Future<List<MedicationModel>> getMedications(String userId) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    try {
      final hiveMeds = _medsBox.values.toList();
      return hiveMeds.map((hiveMed) => _convertHiveMedToModel(hiveMed)).toList();
    } catch (e) {
      throw Exception('Get medications error: $e');
    }
  }

  /* ---------- UPDATE ---------- */
  Future<void> updateMedication(String id, MedicationModel med) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    try {
      // Find and update the medication
      for (int i = 0; i < _medsBox.length; i++) {
        final existingMed = _medsBox.getAt(i);
        if (existingMed?.id == id) {
          final updatedMed = Med(
            id: existingMed!.id,
            name: med.medicationName ?? existingMed.name,
            dosage: med.dosage ?? existingMed.dosage,
            type: med.type ?? existingMed.type,
            scheduleTimes: med.scheduleTimes ?? [], // Direct mapping
            startAt: med.startDate!,
            endAt: _calculateEndDate(med.startDate!, med.duration),
          );

          await _medsBox.putAt(i, updatedMed);

          // 🔥 FIXED: Using correct NotificationService methods
          await NotificationService.instance.cancelForMedicine(id);
          await _scheduleNotificationsForMed(updatedMed);
          break;
        }
      }
    } catch (e) {
      throw Exception('Update medication error: $e');
    }
  }

  /* ---------- DELETE ---------- */
  Future<void> deleteMedication(String id) async {
    await _ensureInitialized(); // Ensure boxes are initialized

    try {
      // Cancel all notifications for this medicine first
      await NotificationService.instance.cancelForMedicine(id);

      for (int i = 0; i < _medsBox.length; i++) {
        final med = _medsBox.getAt(i);
        if (med?.id == id) {
          await _medsBox.deleteAt(i);
          break;
        }
      }
    } catch (e) {
      throw Exception('Delete medication error: $e');
    }
  }

  /* ---------- NOTIFICATION SCHEDULING ---------- */

  /// 🔥 UPDATED: Using your Android-optimized NotificationService methods
  Future<void> _scheduleNotificationsForMed(Med med) async {
    try {
      // Convert TimeOfDay list directly (no parsing needed)
      final dailyTimes = med.scheduleTimes.cast<TimeOfDay>();
      
      debugPrint('📱 Scheduling notifications for ${med.name}');
      debugPrint('Daily times: $dailyTimes'); // Debug
      
      final days = med.endAt?.difference(med.startAt).inDays ?? 30; // Default 30 days if indefinite
      debugPrint('Duration: $days days'); // Debug
      
      // Use your Android-optimized bulk scheduling method
      await NotificationService.instance.scheduleAllTreatmentReminders(
        medicineId: med.id,
        medicineName: med.name,
        dosage: med.dosage,
        dailyTimes: dailyTimes,
        durationDays: days,
      );
      
      debugPrint('✅ Successfully scheduled notifications for ${med.name}');
    } catch (e) {
      debugPrint('❌ Notification scheduling failed for ${med.name}: $e');
      rethrow; // Don't hide the error
    }
  }

  /// Reschedule notifications with settings (for ViewModel compatibility)
  Future<void> rescheduleNotificationsForMed(
    Med med, 
    NotificationSettings settings
  ) async {
    try {
      final dailyTimes = med.scheduleTimes.cast<TimeOfDay>();
      final days = med.endAt?.difference(med.startAt).inDays ?? 30;
      
      await NotificationService.instance.rescheduleAllForMedicine(
        medicineId: med.id,
        medicineName: med.name,
        dosage: med.dosage,
        dailyTimes: dailyTimes,
        durationDays: days,
        settings: settings,
      );
    } catch (e) {
      debugPrint('❌ Notification rescheduling failed for ${med.name}: $e');
      rethrow;
    }
  }

  /* ---------- NOTIFICATION UTILITIES ---------- */

  /// Get notification counts by medicine ID
  Future<Map<String, int>> getNotificationCounts() async {
    try {
      return await NotificationService.instance.getScheduledCountByMedicine();
    } catch (e) {
      debugPrint('❌ Failed to get notification counts: $e');
      return {};
    }
  }

  /// Get total scheduled notifications count
  Future<int> getTotalScheduledNotifications() async {
    try {
      return await NotificationService.instance.scheduledCount;
    } catch (e) {
      debugPrint('❌ Failed to get total scheduled count: $e');
      return 0;
    }
  }

  /// Check if notifications are properly configured
  Future<bool> areNotificationsReady() async {
    try {
      return await NotificationService.instance.hasPermissions;
    } catch (e) {
      debugPrint('❌ Failed to check notification permissions: $e');
      return false;
    }
  }

  /// Send test notification
  Future<bool> sendTestNotification() async {
    try {
      return await NotificationService.instance.sendTestNotification();
    } catch (e) {
      debugPrint('❌ Failed to send test notification: $e');
      return false;
    }
  }

  /* ---------- LOG METHODS ---------- */

  Future<List<LogModel>> getLogsByMedId(String medId) async {
    await _ensureInitialized(); // Ensure boxes are initialized

    try {
      return _logsBox.values
          .where((log) => log.medId == medId)
          .toList();
    } catch (e) {
      throw Exception('Get logs error: $e');
    }
  }

  /* ---------- HELPER METHODS ---------- */
  
  // Calculate end date from duration string
  DateTime? _calculateEndDate(DateTime startDate, String? duration) {
    if (duration == null || duration == 'indefinitely') {
      return null; // Indefinite treatment
    }

    final parts = duration.split(' ');
    if (parts.length >= 2) {
      final number = int.tryParse(parts[0]);
      if (number != null) {
        if (duration.contains('day')) {
          return startDate.add(Duration(days: number));
        } else if (duration.contains('week')) {
          return startDate.add(Duration(days: number * 7));
        } else if (duration.contains('month')) {
          return DateTime(startDate.year, startDate.month + number, startDate.day);
        } else if (duration.contains('year')) {
          return DateTime(startDate.year + number, startDate.month, startDate.day);
        }
      }
    }
    
    return startDate.add(const Duration(days: 7)); // Default 7 days
  }

  // Convert Hive Med back to MedicationModel
  MedicationModel _convertHiveMedToModel(Med hiveMed) {
    return MedicationModel(
      id: hiveMed.id,
      medicationName: hiveMed.name,
      dosage: hiveMed.dosage,
      type: hiveMed.type,
      startDate: hiveMed.startAt,
      scheduleTimes: hiveMed.scheduleTimes, // Direct mapping
      duration: hiveMed.endAt == null 
          ? 'indefinitely' 
          : '${hiveMed.endAt!.difference(hiveMed.startAt).inDays} days',
    );
  }

  /* ---------- BATCH OPERATIONS ---------- */

  /// Reschedule all medications (useful after settings changes)
  Future<void> rescheduleAllMedications(NotificationSettings settings) async {
    await _ensureInitialized();
    
    try {
      final hiveMeds = _medsBox.values.toList();
      
      // Cancel all existing notifications
      await NotificationService.instance.cancelAllNotifications();
      
      // Reschedule each medication if notifications are enabled
      if (settings.notificationsEnabled) {
        for (final med in hiveMeds) {
          await rescheduleNotificationsForMed(med, settings);
        }
      }
      
      debugPrint('✅ Rescheduled notifications for ${hiveMeds.length} medications');
    } catch (e) {
      debugPrint('❌ Failed to reschedule all medications: $e');
      throw Exception('Reschedule all medications error: $e');
    }
  }

  /// Get medication statistics
  Future<Map<String, dynamic>> getMedicationStats() async {
    await _ensureInitialized();
    
    try {
      final hiveMeds = _medsBox.values.toList();
      final notificationCounts = await getNotificationCounts();
      final totalScheduled = await getTotalScheduledNotifications();
      
      return {
        'totalMedications': hiveMeds.length,
        'activeMedications': hiveMeds.where((med) => 
          med.endAt == null || med.endAt!.isAfter(DateTime.now())
        ).length,
        'totalScheduledNotifications': totalScheduled,
        'notificationsByMedicine': notificationCounts,
        'hasNotificationPermissions': await areNotificationsReady(),
      };
    } catch (e) {
      debugPrint('❌ Failed to get medication stats: $e');
      return {};
    }
  }
}