import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart';
import '/data/models/log.dart';
import 'analysis_model.dart';
import 'package:flutter/material.dart';

/// Service to fetch and aggregate medication adherence data for analysis views.
/// FIXED: Now returns complete data ranges (all days in month, all 7 days in week)
class AnalysisService {
  late Box<Med> _medsBox;
  late Box<LogModel> _logsBox;

  bool _isInitialized = false;

  /// Grace period after scheduled time before marking as missed
  /// Must match LogService.GRACE_PERIOD for consistency
  static const Duration GRACE_PERIOD = Duration(hours: 2);

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    _medsBox = Hive.box<Med>('meds');
    _logsBox = Hive.box<LogModel>('logs');
    _isInitialized = true;
  }

  Future<void> init() async {
    await _ensureInitialized();
  }

  // === PUBLIC API METHODS ===

  /// Returns today's schedules with status for each dose.
  /// Status: 'taken', 'missed', or 'not_logged'
  /// NOW INCLUDES TIME-BASED MISS DETECTION
  Future<List<DailyTile>> getDailyData(String date) async {
    await _ensureInitialized();

    try {
      final targetDate = DateTime.parse(date);
      final targetDateNormalized = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final result = <DailyTile>[];

      for (final med in _medsBox.values) {
        if (!_isMedicationActiveOnDate(med, targetDateNormalized)) continue;

        LogModel? logForDate;
        try {
          logForDate = _logsBox.values.firstWhere(
            (log) =>
                log.medId == med.id &&
                _isSameDay(log.date, targetDateNormalized),
          );
        } on StateError {
          logForDate = null;
        }

        for (int i = 0; i < med.scheduleTimes.length; i++) {
          final TimeOfDay scheduledTime = med.scheduleTimes[i];
          String status;

          // TIME-AWARE STATUS LOGIC
          if (logForDate != null &&
              i < logForDate.takenScheduleIndices.length) {
            if (logForDate.takenScheduleIndices[i] == 1) {
              status = 'taken';
            } else if (logForDate.percent == 0.1) {
              // 0.1% sentinel - check time
              if (_isPastDeadline(scheduledTime, targetDateNormalized)) {
                status = 'missed'; // Time-based miss
              } else {
                status = 'not_logged'; // Still pending
              }
            } else {
              status = 'missed'; // Explicit miss
            }
          } else {
            // No log - check time
            if (_isPastDeadline(scheduledTime, targetDateNormalized)) {
              status = 'missed'; // Time-based miss
            } else {
              status = 'not_logged'; // Future or within grace
            }
          }

          result.add(
            DailyTile(
              name: med.name,
              time: _formatTimeOfDay(scheduledTime),
              status: status,
            ),
          );
        }
      }

      result.sort((a, b) => a.time.compareTo(b.time));
      return result;
    } catch (e) {
      debugPrint('Error in AnalysisService.getDailyData: $e');
      return [];
    }
  }

  /// Returns daily pie chart data: taken/missed/not_logged percentages
  /// NOW INCLUDES TIME-BASED MISS DETECTION
  Future<Map<String, double>> getDailyPieChartData(String date) async {
    await _ensureInitialized();

    try {
      final targetDate = DateTime.parse(date);
      final targetDateNormalized = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );

      int takenCount = 0;
      int missedCount = 0;
      int notLoggedCount = 0;
      int totalSchedules = 0;

      for (final med in _medsBox.values) {
        if (!_isMedicationActiveOnDate(med, targetDateNormalized)) continue;

        LogModel? log;
        try {
          log = _logsBox.values.firstWhere(
            (l) =>
                l.medId == med.id && _isSameDay(l.date, targetDateNormalized),
          );
        } on StateError {
          log = null;
        }

        for (int i = 0; i < med.scheduleTimes.length; i++) {
          final scheduledTime = med.scheduleTimes[i];
          totalSchedules++;

          // TIME-AWARE COUNTING LOGIC
          if (log != null && i < log.takenScheduleIndices.length) {
            if (log.takenScheduleIndices[i] == 1) {
              takenCount++;
            } else if (log.percent == 0.1) {
              // 0.1% sentinel - check time
              if (_isPastDeadline(scheduledTime, targetDateNormalized)) {
                missedCount++;
              } else {
                notLoggedCount++;
              }
            } else {
              missedCount++;
            }
          } else {
            // No log - check time
            if (_isPastDeadline(scheduledTime, targetDateNormalized)) {
              missedCount++;
            } else {
              notLoggedCount++;
            }
          }
        }
      }

      if (totalSchedules == 0) {
        return {'taken': 0.0, 'missed': 0.0, 'not_logged': 0.0};
      }

      return {
        'taken': (takenCount / totalSchedules) * 100,
        'missed': (missedCount / totalSchedules) * 100,
        'not_logged': (notLoggedCount / totalSchedules) * 100,
      };
    } catch (e) {
      debugPrint('Error in AnalysisService.getDailyPieChartData: $e');
      return {'taken': 0.0, 'missed': 0.0, 'not_logged': 0.0};
    }
  }

  /// Returns complete weekly analysis data including overall adherence,
  /// per-medication breakdown, and insights
  /// FIXED: Now ALWAYS returns all 7 days (Mon-Sun) with 0% for missing days
  Future<WeeklyAnalysisData> getWeeklyDataComplete(
    String startDate,
    String endDate,
  ) async {
    await _ensureInitialized();

    try {
      final startDt = DateTime.parse(startDate);
      final endDt = DateTime.parse(endDate);
      final startNormalized = DateTime(
        startDt.year,
        startDt.month,
        startDt.day,
      );
      final endNormalized = DateTime(endDt.year, endDt.month, endDt.day);

      final medications = _medsBox.values.toList();

      const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

      // FIXED: Initialize all 7 days with 0.0
      final overallAdherence = <String, double>{
        'mon': 0.0,
        'tue': 0.0,
        'wed': 0.0,
        'thu': 0.0,
        'fri': 0.0,
        'sat': 0.0,
        'sun': 0.0,
      };

      final perMedicationData = <String, Map<String, double>>{};
      final medicationNames = <String>[];

      if (medications.isEmpty) {
        return WeeklyAnalysisData(
          overallAdherence: overallAdherence,
          medications: [],
          perMedicationData: {},
          insight: WeeklyInsight(
            overallAdherence: 0.0,
            totalMedications: 0,
            medicationAdherence: {},
          ),
        );
      }

      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);

      for (final med in medications) {
        // FIXED: Initialize all 7 days for each medication
        final tempMedData = <String, double>{
          'mon': 0.0,
          'tue': 0.0,
          'wed': 0.0,
          'thu': 0.0,
          'fri': 0.0,
          'sat': 0.0,
          'sun': 0.0,
        };

        final relevantLogs = <LogModel>[];
        for (final log in _logsBox.values) {
          if (log.medId == med.id &&
              !log.date.isBefore(startNormalized) &&
              !log.date.isAfter(endNormalized)) {
            relevantLogs.add(log);
          }
        }

        final logMap = <String, LogModel>{
          for (final log in relevantLogs) _formatDate(log.date): log,
        };

        bool hasAnyActiveDay = false;

        for (int i = 0; i < 7; i++) {
          final dayDate = startNormalized.add(Duration(days: i));

          // Skip future days
          if (dayDate.isAfter(todayNormalized)) continue;

          final dayKey = dayKeys[i];
          final dateKey = _formatDate(dayDate);

          if (!_isMedicationActiveOnDate(med, dayDate)) continue;

          hasAnyActiveDay = true;

          // Check if today with no logs and no past deadlines
          if (_isSameDay(dayDate, todayNormalized) &&
              !logMap.containsKey(dateKey)) {
            bool anyPastDeadline = false;
            for (final schedTime in med.scheduleTimes) {
              if (_isPastDeadline(schedTime, dayDate)) {
                anyPastDeadline = true;
                break;
              }
            }

            if (!anyPastDeadline) {
              // All doses still pending - skip this day
              continue;
            }
            // else: has past deadlines, keep 0.0
          }

          double dayPercent = 0.0;

          if (logMap.containsKey(dateKey)) {
            final log = logMap[dateKey]!;
            if (log.percent == 0.1) {
              // Check if this is a past date or today with all deadlines passed
              bool allPast = true;
              for (final schedTime in med.scheduleTimes) {
                if (!_isPastDeadline(schedTime, dayDate)) {
                  allPast = false;
                  break;
                }
              }
              dayPercent = allPast ? 0.0 : 0.1;
            } else {
              dayPercent = log.percent;
            }
          }

          // Only set if not 0.1 (pending)
          if (dayPercent != 0.1) {
            tempMedData[dayKey] = dayPercent;
          }
        }

        // Only add medication if it was active during the week
        if (hasAnyActiveDay) {
          medicationNames.add(med.name);
          perMedicationData[med.name] = tempMedData;
        }
      }

      // Calculate overall adherence for each day
      for (int i = 0; i < 7; i++) {
        final dayDate = startNormalized.add(Duration(days: i));
        if (dayDate.isAfter(todayNormalized)) continue;

        final dayKey = dayKeys[i];

        double totalPercent = 0.0;
        int medicationCount = 0;

        for (final medName in medicationNames) {
          if (perMedicationData[medName]!.containsKey(dayKey)) {
            final percent = perMedicationData[medName]![dayKey]!;
            // Exclude 0.1% from averages (still has pending doses)
            if (percent != 0.1) {
              totalPercent += percent;
              medicationCount++;
            }
          }
        }

        overallAdherence[dayKey] = medicationCount > 0
            ? totalPercent / medicationCount
            : 0.0;
      }

      double overallSum = 0.0;
      int dayCount = 0;

      for (int i = 0; i < 7; i++) {
        final dayDate = startNormalized.add(Duration(days: i));
        if (dayDate.isAfter(todayNormalized)) continue;

        final dayKey = dayKeys[i];
        overallSum += overallAdherence[dayKey]!;
        dayCount++;
      }

      final avgAdherence = dayCount > 0 ? overallSum / dayCount : 0.0;

      final medicationAdherence = <String, double>{};
      for (final medName in medicationNames) {
        double medSum = 0.0;
        int medDayCount = 0;

        for (final dayPercent in perMedicationData[medName]!.values) {
          // Exclude 0.1% from averages
          if (dayPercent != 0.1) {
            medSum += dayPercent;
            medDayCount++;
          }
        }

        medicationAdherence[medName] = medDayCount > 0
            ? medSum / medDayCount
            : 0.0;
      }

      final insight = WeeklyInsight(
        overallAdherence: avgAdherence,
        totalMedications: medications.length,
        medicationAdherence: medicationAdherence,
      );

      return WeeklyAnalysisData(
        overallAdherence: overallAdherence,
        medications: medicationNames,
        perMedicationData: perMedicationData,
        insight: insight,
      );
    } catch (e) {
      debugPrint('Error in AnalysisService.getWeeklyDataComplete: $e');
      return WeeklyAnalysisData(
        overallAdherence: {
          'mon': 0.0,
          'tue': 0.0,
          'wed': 0.0,
          'thu': 0.0,
          'fri': 0.0,
          'sat': 0.0,
          'sun': 0.0,
        },
        medications: [],
        perMedicationData: {},
        insight: WeeklyInsight(
          overallAdherence: 0.0,
          totalMedications: 0,
          medicationAdherence: {},
        ),
      );
    }
  }

  Future<Map<String, double>> getWeeklyData(
    String startDate,
    String endDate,
  ) async {
    final weeklyData = await getWeeklyDataComplete(startDate, endDate);
    return weeklyData.overallAdherence;
  }

  Future<Map<String, double>> getWeeklyMedicineData(
    String medicineId,
    String startDate,
    String endDate,
  ) async {
    await _ensureInitialized();

    try {
      final startDt = DateTime.parse(startDate);
      final endDt = DateTime.parse(endDate);
      final startNormalized = DateTime(
        startDt.year,
        startDt.month,
        startDt.day,
      );
      final endNormalized = DateTime(endDt.year, endDt.month, endDt.day);

      final weekData = _emptyWeek<double>();

      final relevantLogs = <LogModel>[];
      for (final log in _logsBox.values) {
        if (log.medId == medicineId &&
            !log.date.isBefore(startNormalized) &&
            !log.date.isAfter(endNormalized)) {
          relevantLogs.add(log);
        }
      }

      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medicineId);
      } on StateError {
        return weekData;
      }

      for (final log in relevantLogs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);

        if (!_isMedicationActiveOnDate(medication, logDate)) continue;

        final abbr = _getDayAbbreviation(logDate);
        if (abbr != null) {
          double percent = log.percent;
          // TIME-AWARE: Check if all schedules past deadline
          if (percent == 0.1) {
            bool allPast = true;
            for (final schedTime in medication.scheduleTimes) {
              if (!_isPastDeadline(schedTime, logDate)) {
                allPast = false;
                break;
              }
            }
            percent = allPast ? 0.0 : 0.1;
          }
          weekData[abbr] = percent == 0.1 ? 0.0 : percent;
        }
      }

      return weekData;
    } catch (e) {
      debugPrint('Error in AnalysisService.getWeeklyMedicineData: $e');
      return _emptyWeek<double>();
    }
  }

  Future<List<DailySummary>> getMonthlySummaryData(String month) async {
    final monthData = await getMonthlyData(month);

    return monthData.entries.map((entry) {
      return DailySummary(
        date: entry.key,
        adherencePercentage: entry.value,
        hasActivity:
            entry.value > 0 || entry.value == 0.0, // Has activity if logged
      );
    }).toList();
  }

  /// FIXED: Returns ALL days in the month (up to today) with 0% for missing days
  /// This ensures the chart always shows the complete month range
  Future<List<ChartDataPoint>> getMonthlyChartData(String month) async {
    await _ensureInitialized();

    try {
      final monthStart = DateTime.parse('$month-01');
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);

      final monthData = await getMonthlyData(month);
      final result = <ChartDataPoint>[];

      // Generate ALL days in the month (up to today)
      for (int day = 1; day <= monthEnd.day; day++) {
        final currentDate = DateTime(monthStart.year, monthStart.month, day);

        // Stop at today for current/future months
        if (currentDate.isAfter(todayNormalized)) break;

        final dateStr = _formatDate(currentDate);
        final value = monthData[dateStr] ?? 0.0;

        result.add(ChartDataPoint(date: dateStr, value: value));
      }

      return result;
    } catch (e) {
      debugPrint('Error in AnalysisService.getMonthlyChartData: $e');
      return [];
    }
  }

  /// Returns month's daily aggregated adherence percentages
  /// TREATS 0.1% AS 0% FOR PAST DATES
  /// Returns month's daily aggregated adherence percentages
  /// NOW RETURNS ALL DAYS IN MONTH (up to today) - missing days default to 0%
  Future<Map<String, double>> getMonthlyData(String month) async {
    await _ensureInitialized();

    try {
      final monthStart = DateTime.parse('$month-01');
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);

      final result = <String, double>{};
      final medications = _medsBox.values.toList();

      if (medications.isEmpty) return result;

      // Collect all logs for the month
      final relevantLogs = <LogModel>[];
      for (final log in _logsBox.values) {
        if (!log.date.isBefore(monthStart) && !log.date.isAfter(monthEnd)) {
          relevantLogs.add(log);
        }
      }

      // Group logs by date
      final dailyLogs = <DateTime, List<LogModel>>{};
      for (final log in relevantLogs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        dailyLogs.putIfAbsent(logDate, () => <LogModel>[]);
        dailyLogs[logDate]!.add(log);
      }

      // Loop through ALL days in the month (up to today)
      for (int day = 1; day <= monthEnd.day; day++) {
        final currentDate = DateTime(monthStart.year, monthStart.month, day);

        // Skip future dates
        if (currentDate.isAfter(todayNormalized)) break;

        final dateStr = _formatDate(currentDate);

        // Check if any medication was active on this date
        bool hasMedicationActive = false;
        for (final med in medications) {
          if (_isMedicationActiveOnDate(med, currentDate)) {
            hasMedicationActive = true;
            break;
          }
        }

        // Skip days with no active medications
        if (!hasMedicationActive) continue;

        // Check if we have logs for this day
        if (dailyLogs.containsKey(currentDate)) {
          // Day with logs - calculate adherence
          final logs = dailyLogs[currentDate]!;
          double totalPercent = 0.0;
          int medicationCount = 0;

          for (final log in logs) {
            Med? med;
            try {
              med = medications.firstWhere((m) => m.id == log.medId);
            } on StateError {
              continue;
            }

            if (!_isMedicationActiveOnDate(med, currentDate)) continue;

            double percent = log.percent;
            // TIME-AWARE: Check if all schedules past deadline
            if (percent == 0.1) {
              bool allPast = true;
              for (final schedTime in med.scheduleTimes) {
                if (!_isPastDeadline(schedTime, currentDate)) {
                  allPast = false;
                  break;
                }
              }
              percent = allPast ? 0.0 : 0.1;
            }

            // Only count if not 0.1 (still has pending doses)
            if (percent != 0.1) {
              totalPercent += percent;
              medicationCount++;
            }
          }

          if (medicationCount > 0) {
            result[dateStr] = totalPercent / medicationCount;
          } else {
            // Logs exist but all pending - check if today
            if (_isSameDay(currentDate, todayNormalized)) {
              // Today with pending doses - don't show 0
              continue;
            } else {
              // Past day with only pending logs - should be 0
              result[dateStr] = 0.0;
            }
          }
        } else {
          // No logs for this day
          if (_isSameDay(currentDate, todayNormalized)) {
            // Today with no logs - check if any schedules are past deadline
            bool anyPastDeadline = false;
            for (final med in medications) {
              if (_isMedicationActiveOnDate(med, currentDate)) {
                for (final schedTime in med.scheduleTimes) {
                  if (_isPastDeadline(schedTime, currentDate)) {
                    anyPastDeadline = true;
                    break;
                  }
                }
              }
              if (anyPastDeadline) break;
            }

            if (anyPastDeadline) {
              // Some doses are past deadline - count as missed
              result[dateStr] = 0.0;
            }
            // else: all doses still pending, don't add to result
          } else {
            // Past day with no logs - definitively missed
            result[dateStr] = 0.0;
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error in AnalysisService.getMonthlyData: $e');
      return {};
    }
  }

  Future<Map<String, double>> getMonthlyMedicineData(
    String medicineId,
    String month,
  ) async {
    await _ensureInitialized();

    try {
      final monthStart = DateTime.parse('$month-01');
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);

      final result = <String, double>{};

      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medicineId);
      } on StateError {
        return result;
      }

      for (final log in _logsBox.values) {
        if (log.medId == medicineId &&
            !log.date.isBefore(monthStart) &&
            !log.date.isAfter(monthEnd)) {
          final logDate = DateTime(log.date.year, log.date.month, log.date.day);

          if (!_isMedicationActiveOnDate(medication, logDate)) continue;

          double percent = log.percent;
          // TIME-AWARE: Check if all schedules past deadline
          if (percent == 0.1) {
            bool allPast = true;
            for (final schedTime in medication.scheduleTimes) {
              if (!_isPastDeadline(schedTime, logDate)) {
                allPast = false;
                break;
              }
            }
            percent = allPast ? 0.0 : 0.1;
          }

          final dateStr = _formatDate(logDate);
          result[dateStr] = percent == 0.1 ? 0.0 : percent;
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error in AnalysisService.getMonthlyMedicineData: $e');
      return {};
    }
  }

  // === PRIVATE HELPER METHODS ===

  /// Checks if a scheduled time has passed its deadline (scheduled time + grace period)
  /// Must match LogService._isPastDeadline() for consistency
  bool _isPastDeadline(TimeOfDay scheduledTime, DateTime date) {
    final now = DateTime.now();

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

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Map<String, T> _emptyWeek<T>() {
    return {
      'mon': T == double ? 0.0 as T : null as T,
      'tue': T == double ? 0.0 as T : null as T,
      'wed': T == double ? 0.0 as T : null as T,
      'thu': T == double ? 0.0 as T : null as T,
      'fri': T == double ? 0.0 as T : null as T,
      'sat': T == double ? 0.0 as T : null as T,
      'sun': T == double ? 0.0 as T : null as T,
    };
  }

  static String? _getDayAbbreviation(DateTime date) {
    try {
      const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      return days[date.weekday - 1];
    } catch (e) {
      debugPrint('Error getting day abbreviation: $e');
      return null;
    }
  }
}
