import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart'; // Hive Med
import '/data/models/log.dart'; // Hive LogModel (with percent and takenScheduleIndices)
// Import the analysis models if they are in a specific location, otherwise assume they are accessible
// import '../analysis_model.dart'; // DailySummary, WeeklyInsight, DailyTile, ChartDataPoint
// For now, we'll assume they are accessible or define minimal versions if needed inline for clarity.
// Let's assume they are accessible.
import 'analysis_model.dart';
import 'package:flutter/material.dart'; // For TimeOfDay, DateTime operations

/// Service to fetch and aggregate medication adherence data for analysis views.
/// Works with the new local-first Hive models (Med, LogModel).
class AnalysisService {
  late Box<Med> _medsBox;
  late Box<LogModel> _logsBox; // Hive LogModel
  
  bool _isInitialized = false;

  /// Ensures that Hive boxes are initialized before any operations.
  /// This method is safe to call multiple times.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    _medsBox = Hive.box<Med>('meds');
    _logsBox = Hive.box<LogModel>('logs');
    _isInitialized = true;
  }

  /// Initializes the service by getting references to the Hive boxes.
  /// Must be called after Hive is initialized.
  /// This method is kept for backward compatibility but now uses _ensureInitialized internally.
  Future<void> init() async {
    await _ensureInitialized();
  }

  // === PUBLIC API METHODS (Aligned with original signatures where possible) ===

  /// Returns today's schedules with current status for individual doses.
  /// Output: List of DailyTile objects representing each scheduled dose.
  Future<List<DailyTile>> getDailyData(String date) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    // Note: Original signature was getDailyData(String userId, String date).
    // In local-first, user context might be implicit or handled by filtering Meds if they have userId.
    // Assuming Meds are for the current user or user context is handled upstream.
    try {
      final targetDate = DateTime.parse(date);
      final targetDateNormalized = DateTime(targetDate.year, targetDate.month, targetDate.day);

      final result = <DailyTile>[];

      // Iterate through all medications
      for (final med in _medsBox.values) {
        // Check if the medication is active on the target date
        if (_isMedicationActiveOnDate(med, targetDateNormalized)) {
          // Find the log for this medication on this date
          LogModel? logForDate;
          try {
            logForDate = _logsBox.values.firstWhere(
              (log) => log.medId == med.id && _isSameDay(log.date, targetDateNormalized),
            );
          } on StateError {
            // No log found for this med on this date. This is fine.
            logForDate = null;
          }

          // Iterate through each scheduled time for this medication
          for (int i = 0; i < med.scheduleTimes.length; i++) {
            final TimeOfDay scheduledTime = med.scheduleTimes[i];
            String status;

            if (logForDate != null && i < logForDate.takenScheduleIndices.length) {
              // Check the status from takenScheduleIndices
              status = logForDate.takenScheduleIndices[i] == 1 ? 'taken' : 'not_logged';
              // Optional: Apply date-based inference for 'missed' if needed
              // if (logForDate.takenScheduleIndices[i] == 0 && targetDateNormalized.isBefore(DateTime.now())) {
              //   status = 'missed'; // Or keep as not_logged based on your UI logic
              // }
            } else {
              // No log or index out of bounds (shouldn't happen if logs are consistent)
              status = 'not_logged';
            }

            result.add(DailyTile(
              name: med.name,
              time: _formatTimeOfDay(scheduledTime), // e.g., "08:00"
              status: status,
            ));
          }
        }
      }

      // Sort the result by time if needed (DailyTile doesn't have a direct time field for sorting,
      // but the UI can sort by the `time` string if necessary, or we could add a DateTime field to DailyTile)
      // For string time "HH:MM", default string sort works.
      result.sort((a, b) => a.time.compareTo(b.time));

      return result;
    } catch (e) {
      debugPrint('Error in AnalysisService.getDailyData: $e');
      // Return empty list on error for UI stability, as per original design principle
      return [];
    }
  }

  /// Returns week's schedules grouped by day abbreviation.
  /// Simplified approach: Returns average adherence % per day.
  /// Output: Map like {'mon': 85.7, 'tue': 100.0, ...}
  /// Or, if UI needs more detail per day: Map<String, List<ChartDataPoint>> where value is list of meds with their %.
  /// Let's go with average % per day for simplicity and leveraging the percent field.
  Future<Map<String, double>> getWeeklyData(String startDate, String endDate) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    // Note: Original signature was getWeeklyData(String userId, String startDate, String endDate).
    try {
      final startDt = DateTime.parse(startDate);
      final endDt = DateTime.parse(endDate);
      // Normalize dates
      final startNormalized = DateTime(startDt.year, startDt.month, startDt.day);
      final endNormalized = DateTime(endDt.year, endDt.month, endDt.day);

      final weekData = _emptyWeek<double>(); // Initialize with 0.0 or some default

      // Get logs within the date range
      final relevantLogs = <LogModel>[];
      for (final log in _logsBox.values) {
        if (!log.date.isBefore(startNormalized) && !log.date.isAfter(endNormalized)) {
          relevantLogs.add(log);
        }
      }

      // Group logs by date and calculate daily average adherence
      final dailyAverages = <DateTime, List<double>>{}; // date -> list of percentages for that day

      for (final log in relevantLogs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        // Ensure the date key exists in the map
        dailyAverages.putIfAbsent(logDate, () => <double>[]);
        // Add the log's percent to the list for that date
        dailyAverages[logDate]!.add(log.percent);
      }

      // Calculate the average for each day and populate the week map
      dailyAverages.forEach((date, percentages) {
        if (percentages.isNotEmpty) {
          final sum = percentages.reduce((a, b) => a + b);
          final average = sum / percentages.length;
          final abbr = _getDayAbbreviation(date);
          if (abbr != null) {
            weekData[abbr] = average; // Update the average for the day
          }
        } else {
            // If no percentages for a day, average remains 0.0 (or handle as needed)
            // The map is already initialized with 0.0
        }
      });

      return weekData;
    } catch (e) {
      debugPrint('Error in AnalysisService.getWeeklyData: $e');
      return _emptyWeek<double>(); // Return empty structure on error
    }
  }
  
  /// Returns specific medicine's weekly schedules.
  /// Returns average adherence % per day for the specified medicine.
  Future<Map<String, double>> getWeeklyMedicineData(String medicineId, String startDate, String endDate) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    try {
      final startDt = DateTime.parse(startDate);
      final endDt = DateTime.parse(endDate);
      final startNormalized = DateTime(startDt.year, startDt.month, startDt.day);
      final endNormalized = DateTime(endDt.year, endDt.month, endDt.day);

      final weekData = _emptyWeek<double>();

      // Get logs for the specific medicine within the date range
      final relevantLogs = <LogModel>[];
      for (final log in _logsBox.values) {
        if (log.medId == medicineId &&
            !log.date.isBefore(startNormalized) &&
            !log.date.isAfter(endNormalized)) {
          relevantLogs.add(log);
        }
      }

      // Group logs by date and calculate daily average adherence (for this one med, it's just the log.percent)
      final dailyAverages = <DateTime, double>{}; // date -> average percent (which is just the percent for one med)

      for (final log in relevantLogs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        dailyAverages[logDate] = log.percent; // One log per med per day, so percent is the value
      }

      // Populate the week map
      dailyAverages.forEach((date, percent) {
        final abbr = _getDayAbbreviation(date);
        if (abbr != null) {
          weekData[abbr] = percent;
        }
      });

      return weekData;
    } catch (e) {
      debugPrint('Error in AnalysisService.getWeeklyMedicineData: $e');
      return _emptyWeek<double>();
    }
  }

  /// Returns month's daily aggregated adherence percentages.
  /// Output: Map<String, double> where key is date ("YYYY-MM-DD") and value is average adherence % for that day.
  Future<Map<String, double>> getMonthlyData(String month) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
    // Note: Original signature was getMonthlyData(String userId, String month).
    try {
      final monthStart = DateTime.parse('$month-01');
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0); // Last day of the month

      final result = <String, double>{};

      // Get logs within the month
      final relevantLogs = <LogModel>[];
      for (final log in _logsBox.values) {
        if (!log.date.isBefore(monthStart) && !log.date.isAfter(monthEnd)) {
          relevantLogs.add(log);
        }
      }

      // Group logs by date and calculate daily average adherence
      final dailyAverages = <DateTime, List<double>>{}; // date -> list of percentages

      for (final log in relevantLogs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        dailyAverages.putIfAbsent(logDate, () => <double>[]);
        dailyAverages[logDate]!.add(log.percent);
      }

      // Calculate the average for each day and add to result map
      dailyAverages.forEach((date, percentages) {
        if (percentages.isNotEmpty) {
          final sum = percentages.reduce((a, b) => a + b);
          final average = sum / percentages.length;
          final dateStr = _formatDate(date);
          result[dateStr] = average;
        }
        // If percentages is empty, the date is not added to the result map, implying 0% or no data.
        // The UI/ViewModel can handle missing dates as needed (e.g., show 0%).
      });

      return result;
    } catch (e) {
      debugPrint('Error in AnalysisService.getMonthlyData: $e');
      return {}; // Return empty map on error
    }
  }
  
  /// Returns specific medicine's monthly aggregates.
  /// Output: Map<String, double> where key is date ("YYYY-MM-DD") and value is adherence % for that day.
  Future<Map<String, double>> getMonthlyMedicineData(String medicineId, String month) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    
     try {
      final monthStart = DateTime.parse('$month-01');
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);

      final result = <String, double>{};

      // Get logs for the specific medicine within the month
      for (final log in _logsBox.values) {
        if (log.medId == medicineId &&
            !log.date.isBefore(monthStart) &&
            !log.date.isAfter(monthEnd)) {
            
            final dateStr = _formatDate(log.date);
            result[dateStr] = log.percent; // One log per med per day
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error in AnalysisService.getMonthlyMedicineData: $e');
      return {}; 
    }
  }

  // === PRIVATE HELPER METHODS ===

  /// Helper method to check if a medication is active on a specific date.
  bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
    final startDate = DateTime(med.startAt.year, med.startAt.month, med.startAt.day);
    if (startDate.isAfter(targetDate)) return false;
    if (med.endAt != null) {
      final endDate = DateTime(med.endAt!.year, med.endAt!.month, med.endAt!.day);
      if (endDate.isBefore(targetDate)) return false;
    }
    return true;
  }

  /// Helper method to check if two dates are the same day.
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Helper to format TimeOfDay to HH:MM string.
  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Helper to format DateTime to YYYY-MM-DD string.
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Returns empty week structure initialized with a default value (e.g., 0.0 for double).
  static Map<String, T> _emptyWeek<T>() {
    return {
      'mon': T == double ? 0.0 as T : null as T, // This is a trick, better to pass default value
      'tue': T == double ? 0.0 as T : null as T,
      'wed': T == double ? 0.0 as T : null as T,
      'thu': T == double ? 0.0 as T : null as T,
      'fri': T == double ? 0.0 as T : null as T,
      'sat': T == double ? 0.0 as T : null as T,
      'sun': T == double ? 0.0 as T : null as T,
    };
  }
  // Better helper for empty week with default value
  // static Map<String, T> _emptyWeekWithValue<T>(T defaultValue) {
  //   return {
  //     'mon': defaultValue,
  //     'tue': defaultValue,
  //     'wed': defaultValue,
  //     'thu': defaultValue,
  //     'fri': defaultValue,
  //     'sat': defaultValue,
  //     'sun': defaultValue,
  //   };
  // }


  /// Converts DateTime to day abbreviation.
  static String? _getDayAbbreviation(DateTime date) {
    try {
      // DateTime.weekday: 1=Monday, 7=Sunday
      const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      return days[date.weekday - 1];
    } catch (e) {
      debugPrint('Error getting day abbreviation: $e');
      return null;
    }
  }
}