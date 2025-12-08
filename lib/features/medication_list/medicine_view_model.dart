import 'package:flutter/material.dart';
import 'service.dart'; // FIXED: correct import path
import 'medicine_model.dart';
import '/data/models/log.dart';

class MedicationDetailViewModel extends ChangeNotifier {
  final MedicationDetailService _service = MedicationDetailService();

  MedicationDetail? _medicationDetail;
  bool _isLoading = false;
  String? _error;
  bool _showMetrics = false;
  String? _selectedDate;
  bool _isInitialized = false;

  // Getters
  MedicationDetail? get medicationDetail => _medicationDetail;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showMetrics => _showMetrics;
  String? get selectedDate => _selectedDate;

  MedicationDetailViewModel() {
    _initService();
  }

  /* ========== INITIALIZATION ========== */

  Future<void> _initService() async {
    try {
      await _service.init();
      _isInitialized = true;
      debugPrint('MedicationDetailService initialized successfully');
    } catch (e) {
      debugPrint("Failed to initialize service: $e");
      _setError("Failed to initialize: $e");
    }
  }

  /* ========== DATA LOADING ========== */

  Future<void> loadMedicine(String medicineId) async {
    _setLoading(true);
    _setError(null);

    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        debugPrint('Service not initialized, initializing now...');
        await _initService();
      }

      _medicationDetail = await _service.getMedicineWithAllLogs(medicineId);

      if (_medicationDetail == null) {
        throw Exception('Medication not found');
      }

      // Debug date ranges
      debugPrint('✅ Medication loaded successfully:');
      debugPrint('   Medication: ${_medicationDetail!.medication.name}');
      debugPrint('   Start Date: ${getStartDate()}');
      debugPrint('   End Date: ${getEndDate()}');
      debugPrint('   Focused Day: ${getFocusedDay()}');
      debugPrint('   Today: ${DateTime.now()}');
      debugPrint('   Total Logs: ${_medicationDetail!.logs.length}');
    } catch (e) {
      _setError(e.toString());
      debugPrint("❌ Error loading medication detail: $e");
    } finally {
      _setLoading(false);
    }
  }

  /* ========== DATE METHODS (CRITICAL FOR CALENDAR) ========== */

  /// Get start date normalized to midnight
  DateTime getStartDate() {
    if (_medicationDetail?.medication == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }

    final startAt = _medicationDetail!.medication.startAt;
    return DateTime(startAt.year, startAt.month, startAt.day);
  }

  /// Get end date, ensuring it's not before today for completed medications
  DateTime getEndDate() {
    if (_medicationDetail?.medication == null) {
      return DateTime.now().add(const Duration(days: 30));
    }

    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final endAt = _medicationDetail!.medication.endAt;

    if (endAt != null) {
      final endDate = DateTime(endAt.year, endAt.month, endAt.day);

      // CRITICAL: For completed medications, extend to today so calendar can display
      if (endDate.isBefore(nowDate)) {
        debugPrint(
          '⚠️ Medication ended in the past, extending to today for calendar view',
        );
        return nowDate;
      }
      return endDate;
    } else {
      // Ongoing medication - extend far into future
      return _medicationDetail!.medication.startAt.add(
        const Duration(days: 365),
      );
    }
  }

  /// Get focused day clamped within valid calendar range (CRITICAL FIX)
  DateTime getFocusedDay() {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final start = getStartDate();
    final end = getEndDate();

    // Clamp focused day within valid range
    if (todayNormalized.isBefore(start)) {
      debugPrint('📅 Today is before start date, focusing on start: $start');
      return start;
    } else if (todayNormalized.isAfter(end)) {
      debugPrint('📅 Today is after end date, focusing on end: $end');
      return end;
    } else {
      return todayNormalized;
    }
  }

  /// Check if date is in medicine's active range
  bool isDateInRange(DateTime date) {
    if (_medicationDetail?.medication == null) return false;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final start = getStartDate();
    final end = getEndDate();

    return (dateOnly.isAfter(start) || isSameDay(dateOnly, start)) &&
        (dateOnly.isBefore(end) || isSameDay(dateOnly, end));
  }

  /* ========== SCHEDULE METHODS ========== */

  /// Get the list of scheduled times for the medication
  List<TimeOfDay> getScheduledTimes() {
    return _medicationDetail?.medication.scheduleTimes ?? [];
  }

  /// Format TimeOfDay for display (e.g., "08:00")
  String formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Get schedule details for selected day (FIXED: bounds checking)
  List<Map<String, dynamic>> getDaySchedules(String dateStr) {
    if (_medicationDetail == null) return [];

    List<Map<String, dynamic>> schedules = [];

    try {
      final date = DateTime.parse(dateStr);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final logForDate = _findLogForDate(date);
      final scheduledTimes = _medicationDetail!.medication.scheduleTimes;

      for (int i = 0; i < scheduledTimes.length; i++) {
        final timeOfDay = scheduledTimes[i];
        String status;

        if (logForDate == null) {
          // No log exists
          if (dateOnly.isBefore(today)) {
            status = 'missed'; // Past date with no log
          } else {
            status = 'pending'; // Future or today
          }
        } else {
          // FIXED: Safe bounds checking
          bool isTaken = false;
          if (i < logForDate.takenScheduleIndices.length) {
            isTaken = (logForDate.takenScheduleIndices[i] == 1);
          }

          if (isTaken) {
            status = 'taken';
          } else {
            // Not taken - determine if missed or pending
            final scheduleDateTime = DateTime(
              dateOnly.year,
              dateOnly.month,
              dateOnly.day,
              timeOfDay.hour,
              timeOfDay.minute,
            );

            if (scheduleDateTime.isBefore(DateTime.now())) {
              status = 'missed';
            } else {
              status = 'pending';
            }
          }
        }

        schedules.add({'time': timeOfDay, 'status': status});
      }
    } catch (e) {
      debugPrint("❌ Error getting day schedules for $dateStr: $e");
    }

    return schedules;
  }

  /* ========== CALENDAR COLOR METHOD (FIXED) ========== */

  /// Get color for calendar day based on adherence
  Color getDayColor(String dateStr) {
    if (_medicationDetail == null) return Colors.grey;

    try {
      final date = DateTime.parse(dateStr);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check if date is in active medication range
      if (!isDateInRange(dateOnly)) {
        return Colors.grey.withOpacity(0.3); // Out of range
      }

      final logForDate = _findLogForDate(date);
      final totalSchedules = _medicationDetail!.medication.scheduleTimes.length;

      if (totalSchedules == 0) return Colors.grey;

      if (logForDate == null) {
        // No log exists
        if (dateOnly.isBefore(today)) {
          return Colors.red; // Past date with no log = missed
        } else {
          return Colors.grey; // Future date, pending
        }
      }

      final takenCount = logForDate.dosesTaken;

      if (takenCount == totalSchedules) {
        return Colors.green; // All taken
      } else if (takenCount > 0) {
        return Colors.orange; // Partial adherence
      } else {
        // None taken
        if (dateOnly.isBefore(today)) {
          return Colors.red; // Missed
        } else {
          return Colors.grey; // Today or future
        }
      }
    } catch (e) {
      debugPrint("❌ Error calculating day color for $dateStr: $e");
      return Colors.grey;
    }
  }

  /* ========== METRICS METHODS (FIXED) ========== */

  /// Calculate overall adherence percentage
  double getAdherencePercentage() {
    if (_medicationDetail == null || _medicationDetail!.logs.isEmpty)
      return 0.0;

    final totalSchedules = _medicationDetail!.medication.scheduleTimes.length;
    if (totalSchedules == 0) return 0.0;

    int totalDosesPossible = _medicationDetail!.logs.length * totalSchedules;
    int totalDosesTaken = 0;

    for (var log in _medicationDetail!.logs) {
      totalDosesTaken += log.dosesTaken;
    }

    if (totalDosesPossible == 0) return 0.0;
    return (totalDosesTaken / totalDosesPossible) * 100;
  }

  /// Get total taken doses
  int getTakenDosesCount() {
    if (_medicationDetail == null) return 0;
    return _medicationDetail!.logs.fold(0, (sum, log) => sum + log.dosesTaken);
  }

  /// Get total missed doses (FIXED: only count past dates)
  int getMissedDosesCount() {
    if (_medicationDetail == null) return 0;
    final totalSchedules = _medicationDetail!.medication.scheduleTimes.length;
    if (totalSchedules == 0) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int missedCount = 0;

    for (var log in _medicationDetail!.logs) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);

      // Only count as missed if the date has passed
      if (logDate.isBefore(today)) {
        final taken = log.dosesTaken;
        missedCount += (totalSchedules - taken);
      }
    }

    return missedCount;
  }

  /// Get current streak (FIXED: stop when broken)
  int getCurrentStreak() {
    if (_medicationDetail == null) return 0;

    final totalSchedules = _medicationDetail!.medication.scheduleTimes.length;
    if (totalSchedules == 0) return 0;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final checkDate = todayStart.subtract(Duration(days: i));

      // Skip dates outside medication range
      if (!isDateInRange(checkDate)) break;

      final logForDate = _findLogForDate(checkDate);

      if (logForDate != null && logForDate.dosesTaken == totalSchedules) {
        streak++;
      } else {
        // Streak broken - stop checking
        break;
      }
    }

    return streak;
  }

  /* ========== VIEW TOGGLE METHODS ========== */

  void toggleView() {
    _showMetrics = !_showMetrics;
    notifyListeners();
  }

  void selectDate(String date) {
    _selectedDate = date;
    notifyListeners();
  }

  /* ========== INTERNAL HELPER METHODS ========== */

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Helper to find the LogModel for a specific date
  LogModel? _findLogForDate(DateTime date) {
    try {
      final targetDate = DateTime(date.year, date.month, date.day);
      for (var log in _medicationDetail!.logs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        if (isSameDay(targetDate, logDate)) {
          return log;
        }
      }
    } catch (e) {
      debugPrint("❌ Error finding log for date: $e");
    }
    return null;
  }

  /// Helper to check if two dates are the same day
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
