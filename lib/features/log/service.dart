import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart'; // Hive Med with List<TimeOfDay> scheduleTimes
import '/data/models/log.dart'; // Global Hive LogModel with takenScheduleIndices
// Import the feature's private models to ensure type compatibility
import 'log_model.dart' as feature; // Adjust path as needed
import 'package:flutter/material.dart'; // For TimeOfDay, DateTime operations

/// LogService acts as an adapter, presenting an API compatible with the old
/// schedule-centric paradigm to the ViewModel, while internally using the
/// new medication-centric Hive models.
class LogService {
  late Box<LogModel> _globalLogsBox; // Global Hive LogModel
  late Box<Med> _medsBox;

  bool _isInitialized = false;

  /// Ensures that Hive boxes are initialized before any operations.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    _medsBox = Hive.box<Med>('meds');
    _globalLogsBox = Hive.box<LogModel>('logs');
    _isInitialized = true;
  }

  /// Initializes the service. For backward compatibility.
  Future<void> init() async {
    await _ensureInitialized();
  }

  // --- Single-Day Methods (Existing API) ---

  /// Get today's schedules for a medicine with their log status
  Future<List<feature.ScheduleLogModelWithLog>> getScheduleLogsForMedicineAndDate({
    required String medicineId,
    required String date, // Format: YYYY-MM-DD
  }) async {
    await _ensureInitialized();

    try {
      final targetDate = DateTime.parse(date);
      final targetDateNormalized = DateTime(targetDate.year, targetDate.month, targetDate.day);

      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medicineId);
      } on StateError {
        throw Exception('Medicine with ID $medicineId not found in Hive');
      }

      if (!_isMedicationActiveOnDate(medication, targetDateNormalized)) {
        return [];
      }

      LogModel? globalLog;
      try {
        globalLog = _globalLogsBox.values.firstWhere(
          (log) => log.medId == medicineId && _isSameDay(log.date, targetDateNormalized),
        );
      } on StateError {
        globalLog = null;
      }

      List<feature.ScheduleLogModelWithLog> result = [];

      for (int i = 0; i < medication.scheduleTimes.length; i++) {
        final TimeOfDay timeOfDay = medication.scheduleTimes[i];
        final syntheticScheduleId = '${medication.id}_$i';
        final timeString = _formatTimeOfDayForApi(timeOfDay);
        final startDateString = medication.startAt.toIso8601String().split('T')[0];
        final endDateString = medication.endAt?.toIso8601String().split('T')[0] ??
            DateTime(targetDateNormalized.year + 1, targetDateNormalized.month, targetDateNormalized.day)
                .toIso8601String()
                .split('T')[0];

        final scheduleLogModel = feature.ScheduleLogModel(
          id: syntheticScheduleId,
          medicineId: medication.id,
          time: timeString,
          startDate: startDateString,
          endDate: endDateString,
          createdAt: medication.startAt,
        );

        feature.LogModel? featureLogModel;
        if (globalLog != null) {
          final status = (globalLog.takenScheduleIndices.length > i && globalLog.takenScheduleIndices[i] == 1)
              ? feature.LogStatus.taken
              : feature.LogStatus.missed;

          featureLogModel = feature.LogModel(
            id: '${globalLog.medId}_${globalLog.date.toIso8601String().split('T')[0]}_$i',
            scheduleId: syntheticScheduleId,
            date: globalLog.date.toIso8601String().split('T')[0],
            status: status,
            createdAt: globalLog.date,
          );
        }

        result.add(feature.ScheduleLogModelWithLog(
          schedule: scheduleLogModel,
          log: featureLogModel,
          scheduleIndex: i,
        ));
      }

      return result;
    } catch (e) {
      throw Exception('Failed to get schedules: $e');
    }
  }

  /// Fetch medication name by ID
  Future<String?> getMedicineName(String medicineId) async {
    await _ensureInitialized();
    try {
      final Med medication = _medsBox.values.firstWhere((med) => med.id == medicineId);
      return medication.name;
    } on StateError {
      return null;
    }
  }

  /// Create a new log entry
  Future<feature.LogModel> createLog({
    required String scheduleId,
    required String date,
    required feature.LogStatus status,
  }) async {
    await _ensureInitialized();
    return await saveLog(scheduleId: scheduleId, status: status, date: date);
  }

  /// Update an existing log by logId
  Future<feature.LogModel> updateLog({
    required String logId,
    required feature.LogStatus status,
  }) async {
    await _ensureInitialized();

    final parts = logId.split('_');
    if (parts.length < 3) {
      throw Exception('Invalid log ID format for update: $logId');
    }
    final medId = parts[0];
    final scheduleIndexStr = parts[parts.length - 1];
    final scheduleIndex = int.tryParse(scheduleIndexStr);
    if (scheduleIndex == null) {
      throw Exception('Could not parse index from log ID for update: $logId');
    }

    final syntheticScheduleId = '${medId}_$scheduleIndex';
    final logDate = DateTime.now().toIso8601String().split('T')[0];

    return await saveLog(scheduleId: syntheticScheduleId, status: status, date: logDate);
  }

  /// Create or update a log (core logic)
  Future<feature.LogModel> saveLog({
    required String scheduleId,
    required feature.LogStatus status,
    String? date,
  }) async {
    await _ensureInitialized();

    try {
      final logDateStr = date ?? DateTime.now().toIso8601String().split('T')[0];
      final targetDate = DateTime.parse(logDateStr);
      final targetDateNormalized = DateTime(targetDate.year, targetDate.month, targetDate.day);

      final parsedIds = _parseScheduleId(scheduleId);
      final medId = parsedIds.medId;
      final scheduleIndex = parsedIds.index;

      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medId);
      } on StateError {
        throw Exception('Medication for schedule ID $scheduleId not found');
      }

      if (scheduleIndex < 0 || scheduleIndex >= medication.scheduleTimes.length) {
        throw Exception('Invalid schedule index $scheduleIndex in ID: $scheduleId');
      }

      LogModel? globalLog;
      int globalLogIndex = -1;
      for (int i = 0; i < _globalLogsBox.length; i++) {
        final log = _globalLogsBox.getAt(i);
        if (log != null && log.medId == medId && _isSameDay(log.date, targetDateNormalized)) {
          globalLog = log;
          globalLogIndex = i;
          break;
        }
      }

      if (globalLog == null) {
        globalLog = LogModel.forMedication(
          medId: medId,
          date: targetDateNormalized,
          scheduleLength: medication.scheduleTimes.length,
        );
        globalLogIndex = await _globalLogsBox.add(globalLog);
      }

      final updatedIndices = List<int>.from(globalLog.takenScheduleIndices);
      updatedIndices[scheduleIndex] = (status == feature.LogStatus.taken) ? 1 : 0;

      final dosesTaken = updatedIndices.where((s) => s == 1).length;
      final newPercent = (dosesTaken / medication.scheduleTimes.length) * 100;

      final updatedGlobalLog = LogModel(
        medId: globalLog.medId,
        date: globalLog.date,
        percent: newPercent,
        takenScheduleIndices: updatedIndices,
      );

      await _globalLogsBox.putAt(globalLogIndex, updatedGlobalLog);

      return feature.LogModel(
        id: '${updatedGlobalLog.medId}_${updatedGlobalLog.date.toIso8601String().split('T')[0]}_$scheduleIndex',
        scheduleId: scheduleId,
        date: updatedGlobalLog.date.toIso8601String().split('T')[0],
        status: status,
        createdAt: updatedGlobalLog.date,
      );
    } catch (e) {
      throw Exception('Failed to save log: $e');
    }
  }

  /// Get specific log for a schedule and date
  Future<feature.LogModel?> getLog({required String scheduleId, String? date}) async {
    await _ensureInitialized();
    try {
      final logDateStr = date ?? DateTime.now().toIso8601String().split('T')[0];
      final parsedIds = _parseScheduleId(scheduleId);
      final medId = parsedIds.medId;

      final logsForDate = await getScheduleLogsForMedicineAndDate(medicineId: medId, date: logDateStr);

      feature.ScheduleLogModelWithLog? matchingScheduleLog;
      try {
        matchingScheduleLog = logsForDate.firstWhere((sl) => sl.schedule.id == scheduleId);
      } on StateError {
        matchingScheduleLog = null;
      }

      return matchingScheduleLog?.log;
    } catch (e) {
      debugPrint('Error in getLog: $e');
      return null;
    }
  }

  /// Delete a log entry (mark as not taken)
  Future<void> deleteLog({required String scheduleId, String? date}) async {
    await _ensureInitialized();
    try {
      final logDateStr = date ?? DateTime.now().toIso8601String().split('T')[0];
      final parsedIds = _parseScheduleId(scheduleId);
      final medId = parsedIds.medId;
      final scheduleIndex = parsedIds.index;

      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medId);
      } on StateError {
        throw Exception('Medication for schedule ID $scheduleId not found');
      }

      if (scheduleIndex < 0 || scheduleIndex >= medication.scheduleTimes.length) {
        throw Exception('Invalid schedule index $scheduleIndex in ID: $scheduleId');
      }

      final targetDate = DateTime.parse(logDateStr);
      final targetDateNormalized = DateTime(targetDate.year, targetDate.month, targetDate.day);

      LogModel? globalLog;
      int globalLogIndex = -1;
      for (int i = 0; i < _globalLogsBox.length; i++) {
        final log = _globalLogsBox.getAt(i);
        if (log != null && log.medId == medId && _isSameDay(log.date, targetDateNormalized)) {
          globalLog = log;
          globalLogIndex = i;
          break;
        }
      }

      if (globalLog != null) {
        final updatedIndices = List<int>.from(globalLog.takenScheduleIndices);
        updatedIndices[scheduleIndex] = 0;

        final dosesTaken = updatedIndices.where((s) => s == 1).length;
        final newPercent = (dosesTaken / medication.scheduleTimes.length) * 100;

        final updatedGlobalLog = LogModel(
          medId: globalLog.medId,
          date: globalLog.date,
          percent: newPercent,
          takenScheduleIndices: updatedIndices,
        );

        await _globalLogsBox.putAt(globalLogIndex, updatedGlobalLog);
      }
    } catch (e) {
      throw Exception('Failed to delete log: $e');
    }
  }

  // --- 🔥 NEW: Multi-Day Log Access Methods ---

  /// Get all logs for a specific medication (across all dates)
  Future<List<LogModel>> getAllLogsForMedicine(String medId) async {
    await _ensureInitialized();
    final allLogs = _globalLogsBox.values.toList();
    final logsForMed = allLogs.where((log) => log.medId == medId).toList();
    logsForMed.sort((a, b) => a.date.compareTo(b.date));
    return logsForMed;
  }
/// Get logs for a medication within a date range (inclusive)
/// Now includes zero-percent entries for days with no logs within the medication's active period
Future<List<LogModel>> getLogsForMedicineAndRange(
  String medId,
  DateTime startDate,
  DateTime endDate,
) async {
  await _ensureInitialized();

  final startNormalized = DateTime(startDate.year, startDate.month, startDate.day);
  final endNormalized = DateTime(endDate.year, endDate.month, endDate.day);

  // Get the medication to check its active period
  Med? medication;
  try {
    medication = _medsBox.values.firstWhere((med) => med.id == medId);
  } on StateError {
    throw Exception('Medicine with ID $medId not found');
  }

  // Determine the actual date range to consider (intersection of query range and medication active period)
  final medStartDate = DateTime(medication.startAt.year, medication.startAt.month, medication.startAt.day);
  final medEndDate = medication.endAt != null 
      ? DateTime(medication.endAt!.year, medication.endAt!.month, medication.endAt!.day)
      : null;

  final actualStartDate = startNormalized.isBefore(medStartDate) ? medStartDate : startNormalized;
  final actualEndDate = medEndDate != null && endNormalized.isAfter(medEndDate) 
      ? medEndDate 
      : endNormalized;

  // If medication period doesn't overlap with query range, return empty
  if (actualStartDate.isAfter(actualEndDate)) {
    return [];
  }

  // Get existing logs in the range
  final allLogs = _globalLogsBox.values.toList();
  final existingLogs = allLogs.where((log) {
    final logDate = DateTime(log.date.year, log.date.month, log.date.day);
    return log.medId == medId &&
           !logDate.isBefore(actualStartDate) &&
           !logDate.isAfter(actualEndDate);
  }).toList();

  // Create a map of existing logs by date for quick lookup
  final existingLogsByDate = <String, LogModel>{};
  for (final log in existingLogs) {
    final dateKey = log.date.toIso8601String().split('T')[0];
    existingLogsByDate[dateKey] = log;
  }

  // Generate complete list including zero-percent days for the active period only
  final completeLogsList = <LogModel>[];
  
  DateTime currentDate = actualStartDate;
  while (!currentDate.isAfter(actualEndDate)) {
    final dateKey = currentDate.toIso8601String().split('T')[0];
    
    if (existingLogsByDate.containsKey(dateKey)) {
      // Use existing log
      completeLogsList.add(existingLogsByDate[dateKey]!);
    } else {
      // Create 0.1% log for missing day within active medication period
      // Using 0.1% to distinguish from actual 0% (missed all doses)
      final notLoggedDayLog = LogModel(
        medId: medId,
        date: currentDate,
        percent: 0.1,
        takenScheduleIndices: List.filled(medication.scheduleTimes.length, 0),
      );
      completeLogsList.add(notLoggedDayLog);
    }
    
    // Move to next day
    currentDate = currentDate.add(Duration(days: 1));
  }

  return completeLogsList;
}

/// Get logs for the current week (Monday to Sunday) with zero-percent days
Future<List<LogModel>> getLogsForThisWeek(String medId) async {
  final today = DateTime.now();
  final weekday = today.weekday; // 1=Mon, 7=Sun
  final monday = today.subtract(Duration(days: weekday - 1));
  final sunday = monday.add(Duration(days: 6));
  return await getLogsForMedicineAndRange(medId, monday, sunday);
}
  // --- Internal Helper Methods ---

  bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
    final startDate = DateTime(med.startAt.year, med.startAt.month, med.startAt.day);
    if (startDate.isAfter(targetDate)) return false;
    if (med.endAt != null) {
      final endDate = DateTime(med.endAt!.year, med.endAt!.month, med.endAt!.day);
      if (endDate.isBefore(targetDate)) return false;
    }
    return true;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  String _formatTimeOfDayForApi(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

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