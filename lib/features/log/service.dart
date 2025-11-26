import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart';
import '/data/models/log.dart';
import 'log_model.dart' as feature;
import 'package:flutter/material.dart';

/// LogService acts as an adapter, presenting an API compatible with the old
/// schedule-centric paradigm to the ViewModel, while internally using the
/// new medication-centric Hive models.
class LogService {
  late Box<LogModel> _globalLogsBox;
  late Box<Med> _medsBox;

  bool _isInitialized = false;

  /// Grace period after scheduled time before marking as missed
  static const Duration GRACE_PERIOD = Duration(hours: 2);

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    _medsBox = Hive.box<Med>('meds');
    _globalLogsBox = Hive.box<LogModel>('logs');
    _isInitialized = true;
  }

  Future<void> init() async {
    await _ensureInitialized();
  }

  // === SINGLE-DAY METHODS ===

  /// Get today's schedules for a medicine with their log status
  /// Now includes time-based miss detection
  Future<List<feature.ScheduleLogModelWithLog>>
  getScheduleLogsForMedicineAndDate({
    required String medicineId,
    required String date,
  }) async {
    await _ensureInitialized();

    try {
      final targetDate = DateTime.parse(date);
      final targetDateNormalized = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );

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
          (log) =>
              log.medId == medicineId &&
              _isSameDay(log.date, targetDateNormalized),
        );
      } on StateError {
        globalLog = null;
      }

      List<feature.ScheduleLogModelWithLog> result = [];

      for (int i = 0; i < medication.scheduleTimes.length; i++) {
        final TimeOfDay timeOfDay = medication.scheduleTimes[i];
        final syntheticScheduleId = '${medication.id}_$i';
        final timeString = _formatTimeOfDayForApi(timeOfDay);
        final startDateString = medication.startAt.toIso8601String().split(
          'T',
        )[0];
        final endDateString =
            medication.endAt?.toIso8601String().split('T')[0] ??
            DateTime(
              targetDateNormalized.year + 1,
              targetDateNormalized.month,
              targetDateNormalized.day,
            ).toIso8601String().split('T')[0];

        final scheduleLogModel = feature.ScheduleLogModel(
          id: syntheticScheduleId,
          medicineId: medication.id,
          time: timeString,
          startDate: startDateString,
          endDate: endDateString,
          createdAt: medication.startAt,
        );

        feature.LogModel? featureLogModel;

        // TIME-AWARE STATUS LOGIC
        if (globalLog != null && i < globalLog.takenScheduleIndices.length) {
          feature.LogStatus status;

          // Check if this is the 0.1% sentinel (placeholder from getLogsForMedicineAndRange)
          if (globalLog.percent == 0.1) {
            // 0.1% means no real log data exists
            // Check if deadline has passed
            if (_isPastDeadline(timeOfDay, targetDateNormalized)) {
              status = feature.LogStatus.missed; // Implicit miss (time-based)
            } else {
              status = feature.LogStatus.notLogged; // Still pending
            }
          } else if (globalLog.takenScheduleIndices[i] == 1) {
            // Explicitly marked as taken
            status = feature.LogStatus.taken;
          } else {
            // Index is 0 with real log data = explicit miss
            status = feature.LogStatus.missed;
          }

          featureLogModel = feature.LogModel(
            id: '${globalLog.medId}_${globalLog.date.toIso8601String().split('T')[0]}_$i',
            scheduleId: syntheticScheduleId,
            date: globalLog.date.toIso8601String().split('T')[0],
            status: status,
            createdAt: globalLog.date,
          );
        } else {
          // No global log exists at all for this medication on this date
          // Check if deadline has passed to create implicit miss
          if (_isPastDeadline(timeOfDay, targetDateNormalized)) {
            featureLogModel = feature.LogModel(
              id: 'implicit_miss_${medication.id}_${targetDateNormalized.toIso8601String().split('T')[0]}_$i',
              scheduleId: syntheticScheduleId,
              date: targetDateNormalized.toIso8601String().split('T')[0],
              status: feature.LogStatus.missed,
              createdAt: DateTime.now(),
            );
          }
          // else: leave featureLogModel as null (not logged, within grace period or future)
        }

        result.add(
          feature.ScheduleLogModelWithLog(
            schedule: scheduleLogModel,
            log: featureLogModel,
            scheduleIndex: i,
          ),
        );
      }

      return result;
    } catch (e) {
      throw Exception('Failed to get schedules: $e');
    }
  }

  Future<String?> getMedicineName(String medicineId) async {
    await _ensureInitialized();
    try {
      final Med medication = _medsBox.values.firstWhere(
        (med) => med.id == medicineId,
      );
      return medication.name;
    } on StateError {
      return null;
    }
  }

  Future<feature.LogModel> createLog({
    required String scheduleId,
    required String date,
    required feature.LogStatus status,
  }) async {
    await _ensureInitialized();
    return await saveLog(scheduleId: scheduleId, status: status, date: date);
  }

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

    return await saveLog(
      scheduleId: syntheticScheduleId,
      status: status,
      date: logDate,
    );
  }

  Future<feature.LogModel> saveLog({
    required String scheduleId,
    required feature.LogStatus status,
    String? date,
  }) async {
    await _ensureInitialized();

    try {
      final logDateStr = date ?? DateTime.now().toIso8601String().split('T')[0];
      final targetDate = DateTime.parse(logDateStr);
      final targetDateNormalized = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );

      final parsedIds = _parseScheduleId(scheduleId);
      final medId = parsedIds.medId;
      final scheduleIndex = parsedIds.index;

      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medId);
      } on StateError {
        throw Exception('Medication for schedule ID $scheduleId not found');
      }

      if (scheduleIndex < 0 ||
          scheduleIndex >= medication.scheduleTimes.length) {
        throw Exception(
          'Invalid schedule index $scheduleIndex in ID: $scheduleId',
        );
      }

      LogModel? globalLog;
      int globalLogIndex = -1;
      for (int i = 0; i < _globalLogsBox.length; i++) {
        final log = _globalLogsBox.getAt(i);
        if (log != null &&
            log.medId == medId &&
            _isSameDay(log.date, targetDateNormalized)) {
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
      updatedIndices[scheduleIndex] = (status == feature.LogStatus.taken)
          ? 1
          : 0;

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

  Future<feature.LogModel?> getLog({
    required String scheduleId,
    String? date,
  }) async {
    await _ensureInitialized();
    try {
      final logDateStr = date ?? DateTime.now().toIso8601String().split('T')[0];
      final parsedIds = _parseScheduleId(scheduleId);
      final medId = parsedIds.medId;

      final logsForDate = await getScheduleLogsForMedicineAndDate(
        medicineId: medId,
        date: logDateStr,
      );

      feature.ScheduleLogModelWithLog? matchingScheduleLog;
      try {
        matchingScheduleLog = logsForDate.firstWhere(
          (sl) => sl.schedule.id == scheduleId,
        );
      } on StateError {
        matchingScheduleLog = null;
      }

      return matchingScheduleLog?.log;
    } catch (e) {
      debugPrint('Error in getLog: $e');
      return null;
    }
  }

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

      if (scheduleIndex < 0 ||
          scheduleIndex >= medication.scheduleTimes.length) {
        throw Exception(
          'Invalid schedule index $scheduleIndex in ID: $scheduleId',
        );
      }

      final targetDate = DateTime.parse(logDateStr);
      final targetDateNormalized = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );

      LogModel? globalLog;
      int globalLogIndex = -1;
      for (int i = 0; i < _globalLogsBox.length; i++) {
        final log = _globalLogsBox.getAt(i);
        if (log != null &&
            log.medId == medId &&
            _isSameDay(log.date, targetDateNormalized)) {
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

  // === MULTI-DAY LOG ACCESS METHODS ===

  Future<List<LogModel>> getAllLogsForMedicine(String medId) async {
    await _ensureInitialized();
    final allLogs = _globalLogsBox.values.toList();
    final logsForMed = allLogs.where((log) => log.medId == medId).toList();
    logsForMed.sort((a, b) => a.date.compareTo(b.date));
    return logsForMed;
  }

  Future<List<LogModel>> getLogsForMedicineAndRange(
    String medId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _ensureInitialized();

    final startNormalized = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endNormalized = DateTime(endDate.year, endDate.month, endDate.day);

    Med? medication;
    try {
      medication = _medsBox.values.firstWhere((med) => med.id == medId);
    } on StateError {
      throw Exception('Medicine with ID $medId not found');
    }

    final medStartDate = DateTime(
      medication.startAt.year,
      medication.startAt.month,
      medication.startAt.day,
    );
    final medEndDate = medication.endAt != null
        ? DateTime(
            medication.endAt!.year,
            medication.endAt!.month,
            medication.endAt!.day,
          )
        : null;

    final actualStartDate = startNormalized.isBefore(medStartDate)
        ? medStartDate
        : startNormalized;
    final actualEndDate =
        medEndDate != null && endNormalized.isAfter(medEndDate)
        ? medEndDate
        : endNormalized;

    if (actualStartDate.isAfter(actualEndDate)) {
      return [];
    }

    final allLogs = _globalLogsBox.values.toList();
    final existingLogs = allLogs.where((log) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);
      return log.medId == medId &&
          !logDate.isBefore(actualStartDate) &&
          !logDate.isAfter(actualEndDate);
    }).toList();

    final existingLogsByDate = <String, LogModel>{};
    for (final log in existingLogs) {
      final dateKey = log.date.toIso8601String().split('T')[0];
      existingLogsByDate[dateKey] = log;
    }

    final completeLogsList = <LogModel>[];

    DateTime currentDate = actualStartDate;
    while (!currentDate.isAfter(actualEndDate)) {
      final dateKey = currentDate.toIso8601String().split('T')[0];

      if (existingLogsByDate.containsKey(dateKey)) {
        completeLogsList.add(existingLogsByDate[dateKey]!);
      } else {
        final notLoggedDayLog = LogModel(
          medId: medId,
          date: currentDate,
          percent: 0.1,
          takenScheduleIndices: List.filled(medication.scheduleTimes.length, 0),
        );
        completeLogsList.add(notLoggedDayLog);
      }

      currentDate = currentDate.add(Duration(days: 1));
    }

    return completeLogsList;
  }

  Future<List<LogModel>> getLogsForThisWeek(String medId) async {
    final today = DateTime.now();
    final weekday = today.weekday;
    final monday = today.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(Duration(days: 6));
    return await getLogsForMedicineAndRange(medId, monday, sunday);
  }

  // === HELPER METHODS ===

  /// Checks if a scheduled time has passed its deadline (scheduled time + grace period)
  bool _isPastDeadline(TimeOfDay scheduledTime, DateTime date) {
    final now = DateTime.now();

    // Only check deadlines for today or past dates
    final dateNormalized = DateTime(date.year, date.month, date.day);
    final todayNormalized = DateTime(now.year, now.month, now.day);

    // Future dates are never past deadline
    if (dateNormalized.isAfter(todayNormalized)) {
      return false;
    }

    // Past dates are always past deadline
    if (dateNormalized.isBefore(todayNormalized)) {
      return true;
    }

    // For today, check actual time
    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    final deadline = scheduled.add(GRACE_PERIOD);

    return now.isAfter(deadline);
  }

  /// Calculates the deadline for a scheduled time (scheduled + grace period)
  DateTime _calculateDeadline(TimeOfDay scheduledTime, DateTime date) {
    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    return scheduled.add(GRACE_PERIOD);
  }

  bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
    final startDate = DateTime(
      med.startAt.year,
      med.startAt.month,
      med.startAt.day,
    );
    if (startDate.isAfter(targetDate)) return false;
    if (med.endAt != null) {
      final endDate = DateTime(
        med.endAt!.year,
        med.endAt!.month,
        med.endAt!.day,
      );
      if (endDate.isBefore(targetDate)) return false;
    }
    return true;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatTimeOfDayForApi(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  ({String medId, int index}) _parseScheduleId(String scheduleId) {
    final lastUnderscoreIndex = scheduleId.lastIndexOf('_');
    if (lastUnderscoreIndex <= 0 ||
        lastUnderscoreIndex == scheduleId.length - 1) {
      throw Exception('Invalid synthetic schedule ID format: $scheduleId');
    }
    final medId = scheduleId.substring(0, lastUnderscoreIndex);
    if (medId.isEmpty) {
      throw Exception('Invalid medId in schedule ID: $scheduleId');
    }
    final indexStr = scheduleId.substring(lastUnderscoreIndex + 1);
    final index = int.tryParse(indexStr);
    if (index == null) {
      throw Exception('Could not parse index from schedule ID: $scheduleId');
    }
    return (medId: medId, index: index);
  }
}
