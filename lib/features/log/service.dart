import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart'; // Hive Med with List<TimeOfDay> scheduleTimes
import '/data/models/log.dart'; // Global Hive LogModel with takenScheduleIndices
// Import the feature's private models to ensure type compatibility
// Make sure the path is correct for your project structure
import 'log_model.dart' as feature; // Adjust path as needed
import 'package:flutter/material.dart'; // For TimeOfDay, DateTime operations
// import 'dart:collection'; // For StateError

/// LogService acts as an adapter, presenting an API compatible with the old
/// schedule-centric paradigm to the ViewModel, while internally using the
/// new medication-centric Hive models.
class LogService {
  late Box<Med> _medsBox;
  late Box<LogModel> _globalLogsBox; // Global Hive LogModel
  
  bool _isInitialized = false;

  /// Ensures that Hive boxes are initialized before any operations.
  /// This method is safe to call multiple times.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    _medsBox = Hive.box<Med>('meds');
    _globalLogsBox = Hive.box<LogModel>('logs');
    _isInitialized = true;
  }

  /// Initializes the service by getting references to the Hive boxes.
  /// Must be called after Hive is initialized.
  /// This method is kept for backward compatibility but now uses _ensureInitialized internally.
  Future<void> init() async {
    await _ensureInitialized();
  }

  // --- Methods matching the expected ViewModel API ---

  /// Get today's schedules for a medicine with their log status
  /// This synthesizes the old schedule-centric view from the new data model.
  Future<List<feature.ScheduleLogModelWithLog>> getScheduleLogsForMedicineAndDate({
    required String medicineId,
    required String date, // Format: YYYY-MM-DD
  }) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    try {
      final targetDate = DateTime.parse(date);
      final targetDateNormalized = DateTime(targetDate.year, targetDate.month, targetDate.day);

      // 1. Find the medication in Hive
      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medicineId);
      } on StateError {
        throw Exception('Medicine with ID $medicineId not found in Hive');
      }

      // 2. Check if medication is active on the target date
      if (!_isMedicationActiveOnDate(medication, targetDateNormalized)) {
        return []; // No active schedules for this date
      }

      // 3. Get the corresponding global log for this medication and date
      LogModel? globalLog;
      try {
        globalLog = _globalLogsBox.values.firstWhere(
          (log) => log.medId == medicineId && _isSameDay(log.date, targetDateNormalized),
        );
      } on StateError {
        // No global log found, which is fine (implies 0% progress)
        globalLog = null;
      }

      // 4. Synthesize ScheduleLogModel and ScheduleLogModelWithLog objects
      // The old API expected one object per *schedule instance*.
      // We need to create one for each *scheduled time of day*.
      List<feature.ScheduleLogModelWithLog> result = [];

      for (int i = 0; i < medication.scheduleTimes.length; i++) {
        final TimeOfDay timeOfDay = medication.scheduleTimes[i];

        // --- Synthesize a ScheduleLogModel ---
        // We need to create a unique "schedule ID" for this time slot.
        final syntheticScheduleId = '${medication.id}_$i';

        // Convert TimeOfDay to a string format compatible with the old model
        final timeString = _formatTimeOfDayForApi(timeOfDay);

        // Use medication's start/end dates for the schedule model fields
        final startDateString = medication.startAt.toIso8601String().split('T')[0];
        final endDateString = medication.endAt?.toIso8601String().split('T')[0] ??
            DateTime(targetDateNormalized.year + 1, targetDateNormalized.month, targetDateNormalized.day)
                .toIso8601String()
                .split('T')[0];

        final scheduleLogModel = feature.ScheduleLogModel(
          id: syntheticScheduleId, // Synthesized ID
          medicineId: medication.id,
          time: timeString, // Formatted time string
          startDate: startDateString,
          endDate: endDateString,
          createdAt: medication.startAt, // Use medication creation/start
        );
        // --- End Synthesize ScheduleLogModel ---

        // --- Create ScheduleLogModelWithLog ---
        // Map the global log and index status to the feature-specific wrapper
        feature.LogModel? featureLogModel;
        if (globalLog != null) {
          // Synthesize a feature.LogModel based on the global log's data for this specific index
          // The ID and schedule_id are synthetic, createdAt can be approximated
          final status = (globalLog.takenScheduleIndices.length > i && globalLog.takenScheduleIndices[i] == 1)
              ? feature.LogStatus.taken
              : feature.LogStatus.missed; // Simplified logic for synthesis

          featureLogModel = feature.LogModel(
            id: '${globalLog.medId}_${globalLog.date.toIso8601String().split('T')[0]}_$i', // Unique ID
            scheduleId: syntheticScheduleId, // Link back to the synthetic schedule
            date: globalLog.date.toIso8601String().split('T')[0],
            status: status,
            createdAt: globalLog.date, // Approximation
          );
        }

        result.add(feature.ScheduleLogModelWithLog(
          schedule: scheduleLogModel,
          log: featureLogModel, // Can be null if no global log
          scheduleIndex: i, // Crucial for mapping back to takenScheduleIndices
        ));
        // --- End Create ScheduleLogModelWithLog ---
      }

      return result;
    } catch (e) {
      // Re-throw with original signature's error message format
      throw Exception('Failed to get schedules: $e');
    }
  }

  /// Fetch medication name by ID
  Future<String?> getMedicineName(String medicineId) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    try {
      final Med medication = _medsBox.values.firstWhere((med) => med.id == medicineId);
      return medication.name;
    } on StateError {
      // Medication not found
      return null; // Or throw, depending on desired behavior of the calling code
    }
  }

  /// Create a new log entry (schedule-centric API)
  /// Internally: Creates or updates the global log for the medication
  Future<feature.LogModel> createLog({
    required String scheduleId,
    required String date,
    required feature.LogStatus status,
  }) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    // Delegate to saveLog with create semantics
    return await saveLog(scheduleId: scheduleId, status: status, date: date);
  }

  /// Update an existing log entry by log ID (schedule-centric API)
  /// Note: The "log ID" here is the synthesized one from the feature model.
  /// We need to parse it to find the correct global log and index.
  Future<feature.LogModel> updateLog({
    required String logId,
    required feature.LogStatus status,
  }) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
     // 1. Parse the logId to get medId, date, and index
      // Assuming logId format: "${medId}_${dateString}_${index}"
      final parts = logId.split('_');
      if (parts.length < 3) {
        throw Exception('Invalid log ID format for update: $logId');
      }
      final medId = parts[0];
      // final dateString = parts[1]; // Not strictly needed if we have logId
      final scheduleIndexStr = parts[parts.length - 1]; // Get last part as index string
      final scheduleIndex = int.tryParse(scheduleIndexStr);

      if (scheduleIndex == null) {
        throw Exception('Could not parse index from log ID for update: $logId');
      }

      // 2. Synthesize a scheduleId to pass to the internal logic
      final syntheticScheduleId = '${medId}_$scheduleIndex';
      
      // 3. Get current date for update (or parse from logId if stored)
      final logDate = DateTime.now().toIso8601String().split('T')[0]; // Simplified

      // 4. Delegate to saveLog with update semantics
      return await saveLog(scheduleId: syntheticScheduleId, status: status, date: logDate);
  }

  /// Create or update a log entry (upsert functionality - schedule-centric API)
  /// This is the core method that handles the translation logic.
  Future<feature.LogModel> saveLog({
    required String scheduleId,
    required feature.LogStatus status,
    String? date,
  }) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    try {
      final logDateStr = date ?? DateTime.now().toIso8601String().split('T')[0];
      final targetDate = DateTime.parse(logDateStr);
      final targetDateNormalized = DateTime(targetDate.year, targetDate.month, targetDate.day);

      // 1. Parse the scheduleId to get medId and index
      final parsedIds = _parseScheduleId(scheduleId);
      final medId = parsedIds.medId;
      final scheduleIndex = parsedIds.index;

      // 2. Find the medication
      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medId);
      } on StateError {
        throw Exception('Medication for schedule ID $scheduleId not found');
      }

      // 3. Validate schedule index
      if (scheduleIndex < 0 || scheduleIndex >= medication.scheduleTimes.length) {
        throw Exception('Invalid schedule index $scheduleIndex in ID: $scheduleId');
      }

      // 4. Find or create the global log for this medication and date
      LogModel? globalLog;
      int globalLogIndex = -1;
      try {
        for (int i = 0; i < _globalLogsBox.length; i++) {
          final log = _globalLogsBox.getAt(i);
          if (log != null && log.medId == medId && _isSameDay(log.date, targetDateNormalized)) {
            globalLog = log;
            globalLogIndex = i;
            break;
          }
        }
      } catch (e) {
        // Error during iteration, treat as not found
        globalLog = null;
        globalLogIndex = -1;
      }

      if (globalLog == null) {
        // Create new global log if it doesn't exist, initialized with all 0s
        globalLog = LogModel.forMedication(
          medId: medId,
          date: targetDateNormalized,
          scheduleLength: medication.scheduleTimes.length,
        );
        globalLogIndex = await _globalLogsBox.add(globalLog);
      }

      // 5. Update the takenScheduleIndices for the specific index
      // Create a new list to ensure Hive detects the change
      final updatedIndices = List<int>.from(globalLog.takenScheduleIndices);
      // Map feature.LogStatus to 1 (taken) or 0 (not taken/missed)
      updatedIndices[scheduleIndex] = (status == feature.LogStatus.taken) ? 1 : 0;

      // 6. Recalculate percentage
      final dosesTaken = updatedIndices.where((s) => s == 1).length;
      final newPercent = (dosesTaken / medication.scheduleTimes.length) * 100;

      // 7. Create updated global log
      final updatedGlobalLog = LogModel(
        medId: globalLog.medId,
        date: globalLog.date,
        percent: newPercent,
        takenScheduleIndices: updatedIndices,
      );

      // 8. Save updated global log
      await _globalLogsBox.putAt(globalLogIndex, updatedGlobalLog);

      // 9. Synthesize and return the feature.LogModel (matching the API signature)
      // Use the scheduleId that was passed in for consistency
      return feature.LogModel(
        id: '${updatedGlobalLog.medId}_${updatedGlobalLog.date.toIso8601String().split('T')[0]}_$scheduleIndex',
        scheduleId: scheduleId, // Original scheduleId passed in
        date: updatedGlobalLog.date.toIso8601String().split('T')[0],
        status: status, // The status that was requested to be set
        createdAt: updatedGlobalLog.date, // Approximation
      );

    } catch (e) {
      throw Exception('Failed to save log: $e');
    }
  }

  /// Get specific log for a schedule and date
  Future<feature.LogModel?> getLog({required String scheduleId, String? date}) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    try {
      final logDateStr = date ?? DateTime.now().toIso8601String().split('T')[0];

      // Parse scheduleId to get medId and index
      final parsedIds = _parseScheduleId(scheduleId);
      final medId = parsedIds.medId;

      // Get the synthesized schedule logs for the date
      final logsForDate = await getScheduleLogsForMedicineAndDate(medicineId: medId, date: logDateStr);

      // Find the one matching the scheduleId
      // --- FIXED: Use try-catch for firstWhere ---
      feature.ScheduleLogModelWithLog? matchingScheduleLog;
      try {
        matchingScheduleLog = logsForDate.firstWhere(
          (sl) => sl.schedule.id == scheduleId,
          // Remove orElse clause
        );
      } on StateError {
        // firstWhere throws StateError if no element is found
        matchingScheduleLog = null;
      }
      // --- END FIX ---

      return matchingScheduleLog?.log; // Return the feature.LogModel or null
    } catch (e) {
      // Handle unexpected errors during the process
      debugPrint('Error in getLog: $e');
      // It's common for this to return null if not found or on error.
      // Depending on ViewModel's error handling expectations, you might return null or re-throw.
      // Returning null is often more robust for a "get" method.
      return null; // Prefer returning null over throwing for a getter-like method
      // throw Exception('Failed to get log: $e'); // Alternative, if ViewModel expects it
    }
  }

  /// Delete a log entry (schedule-centric API)
  /// Implementation: Mark the specific schedule index as not taken (0) in the global log
  Future<void> deleteLog({required String scheduleId, String? date}) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    try {
      final logDateStr = date ?? DateTime.now().toIso8601String().split('T')[0];

      // Parse scheduleId
      final parsedIds = _parseScheduleId(scheduleId);
      final medId = parsedIds.medId;
      final scheduleIndex = parsedIds.index;

      // Find medication
      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medId);
      } on StateError {
        throw Exception('Medication for schedule ID $scheduleId not found');
      }

      // Validate index
      if (scheduleIndex < 0 || scheduleIndex >= medication.scheduleTimes.length) {
        throw Exception('Invalid schedule index $scheduleIndex in ID: $scheduleId');
      }

      // Find global log
      final targetDate = DateTime.parse(logDateStr);
      final targetDateNormalized = DateTime(targetDate.year, targetDate.month, targetDate.day);

      LogModel? globalLog;
      int globalLogIndex = -1;
      try {
        for (int i = 0; i < _globalLogsBox.length; i++) {
          final log = _globalLogsBox.getAt(i);
          if (log != null && log.medId == medId && _isSameDay(log.date, targetDateNormalized)) {
            globalLog = log;
            globalLogIndex = i;
            break;
          }
        }
      } catch (e) {
        globalLog = null;
        globalLogIndex = -1;
      }

      if (globalLog != null) {
        // Mark the specific schedule as "not taken"
        final updatedIndices = List<int>.from(globalLog.takenScheduleIndices);
        updatedIndices[scheduleIndex] = 0;

        // Recalculate percentage
        final dosesTaken = updatedIndices.where((s) => s == 1).length;
        final newPercent = (dosesTaken / medication.scheduleTimes.length) * 100;

        // Create updated global log
        final updatedGlobalLog = LogModel(
          medId: globalLog.medId,
          date: globalLog.date,
          percent: newPercent,
          takenScheduleIndices: updatedIndices,
        );

        // Save updated global log
        await _globalLogsBox.putAt(globalLogIndex, updatedGlobalLog);
      }
      // If global log doesn't exist, deleting is a no-op, which is fine.
    } catch (e) {
      throw Exception('Failed to delete log: $e');
    }
  }

  // --- Internal Helper Methods ---

  /// Helper method to check if a medication is active on a specific date
  bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
    final startDate = DateTime(med.startAt.year, med.startAt.month, med.startAt.day);
    if (startDate.isAfter(targetDate)) return false;
    if (med.endAt != null) {
      final endDate = DateTime(med.endAt!.year, med.endAt!.month, med.endAt!.day);
      if (endDate.isBefore(targetDate)) return false;
    }
    return true;
  }

  /// Helper method to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Helper to format TimeOfDay for API compatibility (matching old model expectations)
  String _formatTimeOfDayForApi(TimeOfDay time) {
    // Match the format expected by _parseTimeOfDay in ScheduleLogModel
    // e.g., "08:00" for 24-hour like in the provided file
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Helper to parse the synthetic schedule ID back into medId and index
  /// Assumes format: "${medId}_${index}" where medId itself might contain underscores
  ({String medId, int index}) _parseScheduleId(String scheduleId) {
    final lastUnderscoreIndex = scheduleId.lastIndexOf('_');
    if (lastUnderscoreIndex <= 0 || lastUnderscoreIndex == scheduleId.length - 1) {
      throw Exception('Invalid synthetic schedule ID format: $scheduleId');
    }
    final medId = scheduleId.substring(0, lastUnderscoreIndex);
    final indexStr = scheduleId.substring(lastUnderscoreIndex + 1);
    final index = int.tryParse(indexStr);
    if (index == null) {
      throw Exception('Could not parse index from schedule ID: $scheduleId');
    }
    return (medId: medId, index: index);
  }
}