import 'package:flutter/material.dart';
import 'log_model.dart' as feature;
import 'service.dart';

/// ViewModel for the logging feature, interacting solely with the LogService adapter.
class LogViewModel extends ChangeNotifier {
  final LogService _logService = LogService();

  // State variables
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  String? _medicineId;
  String? _medicineName;

  List<feature.ScheduleLogModelWithLog> _scheduleLogModels = [];
  feature.ScheduleLogModelWithLog? _selectedSchedule;

  late DateTime _todaysDate;
  String get todaysDate => _todaysDate.toIso8601String().split('T')[0];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get medicineId => _medicineId;
  String? get medicineName => _medicineName;
  List<feature.ScheduleLogModelWithLog> get scheduleLogModels =>
      _scheduleLogModels;
  feature.ScheduleLogModelWithLog? get selectedSchedule => _selectedSchedule;

  bool get canSubmit => _selectedSchedule != null;
  bool get hasSchedules => _scheduleLogModels.isNotEmpty;
  bool get hasError => _errorMessage != null;
  bool get hasSuccess => _successMessage != null;

  // NEW: Computed properties for UI
  int get dailyTotalDoses => _scheduleLogModels.length;

  int get dailyTakenDoses => _scheduleLogModels.where((s) => s.isTaken).length;

  int get dailyMissedDoses =>
      _scheduleLogModels.where((s) => s.isMissed).length;

  int get dailyNotLoggedDoses =>
      _scheduleLogModels.where((s) => s.isNotLogged).length;

  double get dailyProgressPercentage {
    if (dailyTotalDoses == 0) return 0.0;
    return (dailyTakenDoses / dailyTotalDoses) * 100;
  }

  bool get hasAnyTakenToday => dailyTakenDoses > 0;

  bool get isFullyCompleteToday =>
      dailyTotalDoses > 0 && dailyTakenDoses == dailyTotalDoses;

  LogViewModel() {
    _todaysDate = DateTime.now();
    _todaysDate = DateTime(
      _todaysDate.year,
      _todaysDate.month,
      _todaysDate.day,
    );
  }

  Future<void> initialize({required String medicineId}) async {
    _medicineId = medicineId;
    _medicineName = null;
    _setLoading(true);
    _clearMessages();

    try {
      _medicineName = await _logService.getMedicineName(medicineId);
      await loadSchedules();
    } catch (e) {
      _setError('Failed to initialize: $e');
      debugPrint('Initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadSchedules() async {
    if (_medicineId == null) return;

    _setLoading(true);
    _clearMessages();

    try {
      _scheduleLogModels = await _logService.getScheduleLogsForMedicineAndDate(
        medicineId: _medicineId!,
        date: todaysDate,
      );

      _autoSelectSchedule();
    } catch (e) {
      _setError('Failed to load schedules: $e');
      debugPrint('Load schedules error: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _autoSelectSchedule() {
    if (_scheduleLogModels.isEmpty) return;

    feature.ScheduleLogModelWithLog? notYetTakenSchedule;
    try {
      notYetTakenSchedule = _scheduleLogModels.firstWhere(
        (scheduleLog) => !scheduleLog.isTaken,
      );
    } on StateError {
      notYetTakenSchedule = _scheduleLogModels.isNotEmpty
          ? _scheduleLogModels.first
          : null;
    }

    setSelectedSchedule(notYetTakenSchedule);
  }

  void setSelectedSchedule(feature.ScheduleLogModelWithLog? schedule) {
    _selectedSchedule = schedule;
    _clearMessages();
    notifyListeners();
  }

  Future<void> submitLogAsTaken() async {
    if (_selectedSchedule == null || _medicineId == null) return;

    _setLoading(true);
    _clearMessages();

    try {
      await _logService.saveLog(
        scheduleId: _selectedSchedule!.schedule.id,
        status: feature.LogStatus.taken,
        date: todaysDate,
      );

      _setSuccess('Dose marked as taken! ✅');
      await loadSchedules();
    } catch (e) {
      _setError('Failed to mark dose as taken: $e');
      debugPrint('Submit log error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> submitLogAsMissed() async {
    if (_selectedSchedule == null || _medicineId == null) return;

    _setLoading(true);
    _clearMessages();

    try {
      await _logService.saveLog(
        scheduleId: _selectedSchedule!.schedule.id,
        status: feature.LogStatus.missed,
        date: todaysDate,
      );

      _setSuccess('Dose marked as missed.');
      await loadSchedules();
    } catch (e) {
      _setError('Failed to mark dose as missed: $e');
      debugPrint('Mark missed log error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// FIXED: Now uses deleteLog() instead of saveLog()
  Future<void> submitLogAsNotTaken() async {
    if (_selectedSchedule == null || _medicineId == null) return;

    _setLoading(true);
    _clearMessages();

    try {
      await _logService.deleteLog(
        scheduleId: _selectedSchedule!.schedule.id,
        date: todaysDate,
      );

      _setSuccess('Dose status reverted.');
      await loadSchedules();
    } catch (e) {
      _setError('Failed to revert dose status: $e');
      debugPrint('Revert log error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    await loadSchedules();
  }

  // NEW: Helper methods for UI rendering

  /// Returns appropriate icon for a dose status
  IconData getDoseStatusIcon(feature.ScheduleLogModelWithLog scheduleLog) {
    if (scheduleLog.isTaken) {
      return Icons.check_circle;
    } else if (scheduleLog.isMissed) {
      return scheduleLog.isExplicitMiss ? Icons.cancel : Icons.access_time;
    } else {
      return Icons.hourglass_empty;
    }
  }

  /// Returns appropriate color for a dose status
  Color getDoseStatusColor(feature.ScheduleLogModelWithLog scheduleLog) {
    if (scheduleLog.isTaken) {
      return const Color(0xFF4CAF50); // Green
    } else if (scheduleLog.isMissed) {
      return scheduleLog.isExplicitMiss
          ? const Color(0xFFF44336) // Red
          : const Color(0xFFFF9800); // Orange
    } else if (scheduleLog.isPast) {
      return const Color(0xFF2196F3); // Blue (within grace)
    } else {
      return const Color(0xFF9E9E9E); // Gray (future)
    }
  }

  /// Returns human-readable status text with context
  String getDoseStatusText(feature.ScheduleLogModelWithLog scheduleLog) {
    return scheduleLog.statusDisplayText;
  }

  /// Returns appropriate action button text for a dose
  String getActionButtonText(feature.ScheduleLogModelWithLog scheduleLog) {
    if (scheduleLog.isTaken) {
      return 'Undo (Mark Not Taken)';
    } else if (scheduleLog.isMissed && scheduleLog.isExplicitMiss) {
      return 'Mark as Taken';
    } else if (scheduleLog.isMissed) {
      return 'Mark as Taken (Late)';
    } else if (scheduleLog.isPast) {
      return 'Mark as Taken';
    } else {
      return 'Mark as Taken';
    }
  }

  /// Returns whether action button should be enabled
  bool canTakeAction(feature.ScheduleLogModelWithLog scheduleLog) {
    // Can always undo a taken dose
    if (scheduleLog.isTaken) return true;

    // Can mark as taken if it's the dose's day (even if future, for flexibility)
    // In stricter mode, could check: return scheduleLog.isPast || within grace period
    return true;
  }

  /// Returns progress text like "2 of 3 doses taken"
  String get progressText {
    return '$dailyTakenDoses of $dailyTotalDoses doses taken';
  }

  /// Format schedule for display (backward compatibility)
  String formatScheduleForDisplay(feature.ScheduleLogModelWithLog scheduleLog) {
    String displayText = scheduleLog.schedule.fullDisplayText;
    String statusIcon = '';
    if (scheduleLog.isLogged) {
      statusIcon = scheduleLog.isTaken ? ' ✅' : ' ⏰';
    }
    return '$displayText$statusIcon';
  }

  /// Get status text for selected schedule (backward compatibility)
  String getStatusText() {
    if (_selectedSchedule == null) return 'No schedule selected';

    if (_selectedSchedule!.isTaken) {
      return 'Status: Taken ✅';
    } else if (_selectedSchedule!.isMissed) {
      if (_selectedSchedule!.isExplicitMiss) {
        return 'Status: Marked as missed ❌';
      } else {
        return 'Status: Missed (deadline passed) ⏰';
      }
    } else if (_selectedSchedule!.isPast) {
      final timeUntil = _selectedSchedule!.timeUntilDeadline;
      if (timeUntil != null) {
        return 'Status: Pending (${_formatDuration(timeUntil)} left) ⏳';
      } else {
        return 'Status: Not logged';
      }
    } else {
      return 'Status: Not yet time ⏳';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}min';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min';
    } else {
      return 'just now';
    }
  }

  // === INTERNAL HELPER METHODS ===

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
