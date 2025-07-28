import 'package:flutter/material.dart';
// --- Make sure these paths are correct for your project structure ---
// Import the feature's private models
import 'log_model.dart' as feature; // LogModel, ScheduleLogModel, ScheduleLogModelWithLog, LogStatus
// Import the updated LogService (adapter)
import 'service.dart'; // The LogService adapter

/// ViewModel for the logging feature, interacting solely with the LogService adapter.
class LogViewModel extends ChangeNotifier {
  final LogService _logService = LogService();

  // State variables
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Medicine data
  String? _medicineId;
  String? _medicineName;

  // Schedule data - List of ScheduleLogModelWithLog representing each scheduled time for the med today
  // This list is now populated directly by the LogService adapter.
  List<feature.ScheduleLogModelWithLog> _scheduleLogModels = [];
  feature.ScheduleLogModelWithLog? _selectedSchedule;

  // Today's date
  late DateTime _todaysDate; // Use DateTime internally
  String get todaysDate => _todaysDate.toIso8601String().split('T')[0]; // Expose as String

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get medicineId => _medicineId;
  String? get medicineName => _medicineName;
  List<feature.ScheduleLogModelWithLog> get scheduleLogModels => _scheduleLogModels;
  feature.ScheduleLogModelWithLog? get selectedSchedule => _selectedSchedule;

  // Computed properties
  bool get canSubmit => _selectedSchedule != null;
  bool get hasSchedules => _scheduleLogModels.isNotEmpty;
  bool get hasError => _errorMessage != null;
  bool get hasSuccess => _successMessage != null;

  // Constructor to initialize date
  LogViewModel() {
    _todaysDate = DateTime.now();
    // Normalize to start of day
    _todaysDate = DateTime(_todaysDate.year, _todaysDate.month, _todaysDate.day);
  }

  // Initialize with medicine ID
  Future<void> initialize({ required String medicineId }) async {
    _medicineId = medicineId;
    _medicineName = null;
    _setLoading(true);
    _clearMessages();

    try {
      // --- CHANGED: Use LogService to get medicine name ---
      _medicineName = await _logService.getMedicineName(medicineId);
      // --- END CHANGE ---

      // Load schedules
      await loadSchedules();
    } catch (e) {
      _setError('Failed to initialize: $e');
      debugPrint('Initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load schedules for the medicine for today
  Future<void> loadSchedules() async {
    if (_medicineId == null) return;

    _setLoading(true);
    _clearMessages();

    try {
      // --- CHANGED: Use LogService adapter to get the fully synthesized list ---
      _scheduleLogModels = await _logService.getScheduleLogsForMedicineAndDate(
        medicineId: _medicineId!,
        date: todaysDate, // Pass the string date
      );
      // --- END CHANGE ---

      // Auto-select the first schedule that hasn't been taken yet, or the first one
      _autoSelectSchedule();

    } catch (e) {
      _setError('Failed to load schedules: $e');
      debugPrint('Load schedules error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Auto-select appropriate schedule
  void _autoSelectSchedule() {
    if (_scheduleLogModels.isEmpty) return;

    // --- FIXED: Correctly handle null check and StateError for firstWhere ---
    feature.ScheduleLogModelWithLog? notYetTakenSchedule;
    try {
      // Find the first schedule that is NOT taken
      notYetTakenSchedule = _scheduleLogModels.firstWhere((scheduleLog) => !scheduleLog.isTaken);
    } on StateError {
      // If all are taken, or list is empty, select the first one (if list is not empty)
      notYetTakenSchedule = _scheduleLogModels.isNotEmpty ? _scheduleLogModels.first : null;
    }
    // --- END FIX ---
    
    setSelectedSchedule(notYetTakenSchedule);
  }

  // Set selected schedule
  void setSelectedSchedule(feature.ScheduleLogModelWithLog? schedule) {
    _selectedSchedule = schedule;
    _clearMessages(); // Clear messages when selection changes
    notifyListeners();
  }

  // Submit the log - Mark the selected schedule time as "Taken"
  Future<void> submitLogAsTaken() async {
    // --- CHANGED: Simplified guard clause ---
    if (_selectedSchedule == null || _medicineId == null) return;
    // --- END CHANGE ---

    _setLoading(true);
    _clearMessages();

    try {
      // --- CHANGED: Use LogService adapter's saveLog method ---
      // The adapter handles the translation from scheduleId/status to updating takenScheduleIndices
      await _logService.saveLog(
        scheduleId: _selectedSchedule!.schedule.id, // Get the synthetic schedule ID
        status: feature.LogStatus.taken, // Map action to feature status
        date: todaysDate, // Use the string date
      );
      // --- END CHANGE ---

      _setSuccess('Dose marked as taken!');

      // Refresh the schedules to show updated status
      await loadSchedules();

    } catch (e) {
      _setError('Failed to mark dose as taken: $e');
      debugPrint('Submit log error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Optional: Submit the log - Mark the selected schedule time as "Missed"
  // This can be implemented by explicitly saving a 'missed' status if your feature requires it.
  // If "missed" just means "not taken by the end of the day", you might not need an explicit action.
  // For now, let's provide a way to explicitly mark as missed.
  Future<void> submitLogAsMissed() async {
    if (_selectedSchedule == null || _medicineId == null) return;

    _setLoading(true);
    _clearMessages();

    try {
      // --- ADDED: Use LogService adapter's saveLog method for 'missed' ---
      await _logService.saveLog(
        scheduleId: _selectedSchedule!.schedule.id,
        status: feature.LogStatus.missed, // Map action to feature status
        date: todaysDate,
      );
      // --- END ADDITION ---

      _setSuccess('Dose marked as missed.');

      // Refresh the schedules to show updated status
      await loadSchedules();

    } catch (e) {
      _setError('Failed to mark dose as missed: $e');
      debugPrint('Mark missed log error: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Optional: Submit the log - Revert the selected schedule time to "Not Taken"
  // This is useful for undoing a "Taken" action.
  Future<void> submitLogAsNotTaken() async {
    if (_selectedSchedule == null || _medicineId == null) return;

    _setLoading(true);
    _clearMessages();

    try {
      // --- ADDED: Use LogService adapter's saveLog method for 'not taken' (essentially missed/toggle) ---
      // The adapter's internal logic should handle setting the index to 0.
      await _logService.saveLog(
        scheduleId: _selectedSchedule!.schedule.id,
        status: feature.LogStatus.missed, // Or define a 'not_taken' status if preferred
        date: todaysDate,
      );
      // --- END ADDITION ---

      _setSuccess('Dose status reverted.');

      // Refresh the schedules to show updated status
      await loadSchedules();

    } catch (e) {
      _setError('Failed to revert dose status: $e');
      debugPrint('Revert log error: $e');
    } finally {
      _setLoading(false);
    }
  }


  // Refresh data
  Future<void> refresh() async {
    await loadSchedules();
  }

  // Format schedule for display - use properties from ScheduleLogModel
  // --- FIXED: Ensure parameter is non-nullable or handle null ---
  String formatScheduleForDisplay(feature.ScheduleLogModelWithLog scheduleLog) {
    // Access the underlying schedule model for display info
    // Assuming feature.ScheduleLogModel has fullDisplayText
    // Parameter 'scheduleLog' is non-nullable, so direct access is safe.
    String displayText = scheduleLog.schedule.fullDisplayText; 
    String statusIcon = '';
    if (scheduleLog.isLogged) {
      statusIcon = scheduleLog.isTaken ? ' ✅' : ' ⏰'; // Clock for logged but not this specific dose
    }
    return '$displayText$statusIcon';
  }
  // --- END FIX ---

  // Get status text for selected schedule
  // --- FIXED: Add explicit null check ---
  String getStatusText() {
    // Explicitly check for null first
    if (_selectedSchedule == null) return 'No schedule selected';

    // Now it's safe to use ! or access properties directly
    if (_selectedSchedule!.isTaken) {
      return 'Status: Taken ✅';
    } else if (_selectedSchedule!.isLogged) {
      // If the overall log exists but this specific dose isn't taken
      return 'Status: Logged (Not this dose)';
    } else if (_selectedSchedule!.isPast) { // Ensure isPast getter exists in ScheduleLogModelWithLog
      return 'Status: Missed ⏰'; // Example logic based on time
    } else {
      return 'Status: Scheduled';
    }
  }
  // --- END FIX ---

  // --- Internal Helper Methods ---

  // Clear all messages
  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    // Do not call notifyListeners here if called from within another state-changing method
    // In this case, it's called from setSelectedSchedule, loadSchedules, submitLogAsTaken, etc.
    // which already call notifyListeners, so calling it here is fine.
    notifyListeners(); 
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  // Set success message
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