import 'package:flutter/material.dart';
// --- Update imports ---
import 'service.dart'; // Updated service
import 'medicine_model.dart'; // New model
// import '/data/models/med.dart'; // Hive Med
import '/data/models/log.dart'; // Hive LogModel
// Assuming AuthService is elsewhere and unchanged
import '../auth/service.dart'; // Adjust path as needed

class MedicationDetailViewModel extends ChangeNotifier {
  // --- Update service type ---
  final MedicationDetailService _service = MedicationDetailService();
  final AuthService _authService = AuthService();

  // --- Update data type ---
  MedicationDetail? _medicationDetail; // Use the new model
  bool _isLoading = false;
  String? _error;
  bool _showMetrics = false; // false = calendar, true = metrics
  String? _selectedDate;

  // Getters (make internal fields private and expose via getters)
  MedicationDetail? get medicationDetail => _medicationDetail;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showMetrics => _showMetrics;
  String? get selectedDate => _selectedDate;

  // Load medicine data
  Future<void> loadMedicine(String medicineId) async {
    // Use internal state setters
    _setLoading(true);
    _setError(null);

    try {
      // Note: If Hive Med needs userId for multi-user support, add it to Med model and service call.
      // For now, assuming medicineId is unique across users or user context is handled elsewhere.
      // final user = _authService.getCurrentUser();
      // if (user == null) throw Exception('No user logged in');

      // --- Update service call ---
      _medicationDetail = await _service.getMedicineWithAllLogs(medicineId);
      // --- End update ---
    } catch (e) {
      // Use internal error setter
      _setError(e.toString());
      debugPrint("Error loading medication detail: $e");
    }

    // Use internal state setter
    _setLoading(false);
  }

  // Switch between calendar and metrics
  void toggleView() {
    _showMetrics = !_showMetrics;
    notifyListeners();
  }

  // Select a date on calendar
  void selectDate(String date) {
    _selectedDate = date;
    notifyListeners();
  }

  // Get start date of medicine
  DateTime getStartDate() {
    if (_medicationDetail?.medication == null) return DateTime.now();

    // Use Hive Med's startAt
    return _medicationDetail!.medication.startAt;
    // If you need the earliest log date as well, you could check logs:
    // final logDates = _medicationDetail!.logs.map((log) => log.date).toList();
    // if (logDates.isNotEmpty) {
    //   logDates.sort();
    //   return logDates.first.isBefore(_medicationDetail!.medication.startAt)
    //       ? logDates.first
    //       : _medicationDetail!.medication.startAt;
    // }
    // return _medicationDetail!.medication.startAt;
  }

  // Get end date of medicine
  DateTime getEndDate() {
    if (_medicationDetail?.medication == null) return DateTime.now().add(const Duration(days: 30));

    // Use Hive Med's endAt, or calculate based on start + duration if needed
    // Hive Med doesn't have duration_days directly, but has endAt
    if (_medicationDetail!.medication.endAt != null) {
      return _medicationDetail!.medication.endAt!;
    } else {
      // If no end date, assume a default or indefinite (e.g., 1 year from start)
      return _medicationDetail!.medication.startAt.add(const Duration(days: 365));
    }
    // If you stored duration logic separately or need to derive:
    // return _medicationDetail!.medication.startAt.add(Duration(days: medicine!.durationDays - 1));
  }

  // --- CHANGED: Rethink expected times based on Hive Med ---
  // Get the list of scheduled times for the medication (from Hive Med)
  List<TimeOfDay> getScheduledTimes() {
    return _medicationDetail?.medication.scheduleTimes ?? [];
  }

  // Format TimeOfDay for display (e.g., "08:00")
  String formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Format TimeOfDay for comparison (e.g., "08:00:00" - if needed, though TimeOfDay is better)
  // String formatTimeOfDayForComparison(TimeOfDay time) {
  //   return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  // }
  // --- END CHANGE ---

  // --- CHANGED: Rethink day color logic for Hive model ---
  // Get color for calendar day based on adherence derived from takenScheduleIndices
  Color getDayColor(String dateStr) {
    if (_medicationDetail == null) return Colors.grey;

    try {
      final date = DateTime.parse(dateStr);
      final logForDate = _findLogForDate(date);

      final totalSchedules = _medicationDetail!.medication.scheduleTimes.length;

      if (totalSchedules == 0) return Colors.grey;

      if (logForDate == null) {
        // No log for this date. If date is in active range, might be pending. Otherwise, grey.
        if (isDateInRange(date)) {
             return Colors.grey; // Or a different color for "no data yet"
        } else {
             return Colors.grey; // Outside active range
        }
      }

      final takenCount = logForDate.dosesTaken; // Use helper from Hive LogModel

      if (takenCount == totalSchedules) {
        return Colors.green; // All taken
      } else if (takenCount > 0) {
        return Colors.yellow; // Partially taken
      } else {
        // None taken. Check if date has passed.
        if (date.isBefore(DateTime.now())) {
          return Colors.red; // Missed (date passed, none taken)
        } else {
          return Colors.grey; // Scheduled but not yet taken/past
        }
      }
    } catch (e) {
      debugPrint("Error calculating day color for $dateStr: $e");
      return Colors.grey; // Default on error
    }
  }
  // --- END CHANGE ---

  // --- CHANGED: Rethink schedule details for Hive model ---
  // Get schedule details for selected day, showing which specific times were taken
  List<Map<String, dynamic>> getDaySchedules(String dateStr) {
    // Return a list of maps: {time: TimeOfDay, status: String}
    if (_medicationDetail == null) return [];

    List<Map<String, dynamic>> schedules = [];

    try {
      final date = DateTime.parse(dateStr);
      final logForDate = _findLogForDate(date);

      final scheduledTimes = _medicationDetail!.medication.scheduleTimes;

      for (int i = 0; i < scheduledTimes.length; i++) {
        final timeOfDay = scheduledTimes[i];
        String status;

        if (logForDate == null) {
          status = 'pending';
        } else {
          // Check the takenScheduleIndices list
          if (i < logForDate.takenScheduleIndices.length && logForDate.takenScheduleIndices[i] == 1) {
            status = 'taken';
          } else {
            // Not taken. Determine if missed or pending based on date.
            if (date.isBefore(DateTime.now())) {
              status = 'missed'; // Date passed
            } else {
              status = 'pending'; // Date is today or in the future
            }
          }
        }

        schedules.add({
          'time': timeOfDay, // Pass TimeOfDay object for flexible formatting
          'status': status,
        });
      }
    } catch (e) {
      debugPrint("Error getting day schedules for $dateStr: $e");
    }

    return schedules;
  }
  // --- END CHANGE ---

  // Calculate overall adherence percentage based on doses taken
  double getAdherencePercentage() {
    if (_medicationDetail == null || _medicationDetail!.logs.isEmpty) return 0.0;

    final totalSchedules = _medicationDetail!.medication.scheduleTimes.length;
    if (totalSchedules == 0) return 0.0;

    int totalDosesPossible = _medicationDetail!.logs.length * totalSchedules;
    int totalDosesTaken = 0;

    for (var log in _medicationDetail!.logs) {
      totalDosesTaken += log.dosesTaken; // Sum doses taken each day
    }

    if (totalDosesPossible == 0) return 0.0;
    return (totalDosesTaken / totalDosesPossible) * 100;
  }

  // Get total taken doses (sum of all taken indices across all logs)
  int getTakenDosesCount() {
    if (_medicationDetail == null) return 0;
    return _medicationDetail!.logs.fold(0, (sum, log) => sum + log.dosesTaken);
  }

  // Get total missed doses (approximation: total possible - taken)
  // Note: This is an approximation because "missed" strictly means "time passed without taking"
  // while takenScheduleIndices only tracks what was marked as taken.
  int getMissedDosesCount() {
    if (_medicationDetail == null) return 0;
    final totalSchedules = _medicationDetail!.medication.scheduleTimes.length;
    if (totalSchedules == 0) return 0;

    int totalDosesPossible = _medicationDetail!.logs.length * totalSchedules;
    int taken = getTakenDosesCount();
    return totalDosesPossible - taken;
    // To be more precise about "missed" (past date, not taken),
    // you'd need to iterate through logs and scheduled times for past dates.
  }

  // Get current streak (consecutive days ending today where all doses were taken)
  int getCurrentStreak() {
    if (_medicationDetail == null) return 0;

    final totalSchedules = _medicationDetail!.medication.scheduleTimes.length;
    if (totalSchedules == 0) return 0;

    final today = DateTime.now();
    int streak = 0;

    // Check each day backwards from today
    for (int i = 0; i < 365; i++) { // Limit check to 1 year back
      final checkDate = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final logForDate = _findLogForDate(checkDate);

      bool fullAdherence = false;
      if (logForDate != null) {
        fullAdherence = (logForDate.dosesTaken == totalSchedules);
      }
      // If no log exists for a past date, it could be considered a break in streak
      // depending on business logic. For simplicity, we'll assume no log = no adherence.
      // If the date is in the future, it shouldn't count.

      if (fullAdherence && !checkDate.isAfter(today)) {
        streak++;
      } else {
        // Break the streak if not fully adhered or if checking future dates improperly
        if(!checkDate.isAfter(today)) { // Only break for past or today
             break;
        }
      }
    }

    return streak;
  }

  // Check if date is in medicine's active range
  bool isDateInRange(DateTime date) {
    if (_medicationDetail?.medication == null) return false;
    final start = getStartDate();
    final end = getEndDate();
    // Check if date is on or after start and on or before end
    return (date.isAfter(start) || isSameDay(date, start)) &&
           (date.isBefore(end) || isSameDay(date, end));
  }

  // --- Internal Helper Methods ---

  // Set loading state and notify
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message and notify
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Helper to find the LogModel for a specific date
  LogModel? _findLogForDate(DateTime date) {
    try {
      // Normalize date to compare only year, month, day
      final targetDate = DateTime(date.year, date.month, date.day);
      for (var log in _medicationDetail!.logs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        if (isSameDay(targetDate, logDate)) {
          return log;
        }
      }
    } catch (e) {
      // Ignore errors in finding log
    }
    return null;
  }

  // Helper to check if two dates are the same day
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void dispose() {
    // If any controllers or subscriptions were added, dispose them here
    super.dispose();
  }
}