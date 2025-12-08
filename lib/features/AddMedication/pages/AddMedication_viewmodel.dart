// ignore_for_file: unused_element

import 'package:flutter/material.dart';
// import '../notifications/notifications_model.dart';
import '../AddMedication_model.dart';
import '../../auth/service.dart';
import '../service.dart';
// import '../notifications/service.dart';

class MedicationViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final MedicationService _medicationService = MedicationService();
  MedicationModel _medication = MedicationModel(startDate: DateTime.now());
  int _currentPage = 0;
  final int _totalPages = 2;
  String? _medicationId; // Store the ID for edit mode
  bool _isLoading = false;

  // Constructor that accepts medicationId for edit mode
  MedicationViewModel({String? medicationId}) {
    _medicationId = medicationId;
    if (_medicationId != null) {
      _loadExistingMedication();
    }
  }

  MedicationModel get medication => _medication;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  double get progress => (_currentPage + 1) / _totalPages;
  bool get isEditMode => _medicationId != null;
  bool get isLoading => _isLoading;

  // Load existing medication for edit mode
  Future<void> _loadExistingMedication() async {
    print('Loading existing medication with ID: $_medicationId');
    if (_medicationId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final user = await _authService.getCurrentUser(); // Added await
      if (user == null) {
        print('Error: No user logged in');
        return;
      }

      // Get all medications and find the one with matching ID
      final medications = await _medicationService.getMedications(user.id);
      final existingMedication = medications.firstWhere(
        (med) => med.id == _medicationId,
        orElse: () => MedicationModel(startDate: DateTime.now()),
      );
      print(existingMedication);
      _medication = existingMedication;
      notifyListeners();
    } catch (e) {
      print('Error loading medication: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update medication data
  void updateMedicationName(String name) {
    _medication.medicationName = name;
    notifyListeners();
  }

  void updateDosage(String dosage) {
    _medication.dosage = dosage;
    notifyListeners();
  }

  void updateMedicationType(String type) {
    _medication.type = type;
    notifyListeners();
  }

  void updateStartDate(DateTime date) {
    _medication.startDate = date;
    notifyListeners();
  }

  // NEW: Update schedule times instead of interval
  void updateScheduleTimes(List<TimeOfDay> times) {
    _medication.scheduleTimes = times;
    notifyListeners();
  }

  // NEW: Add a single time to schedule
  void addScheduleTime(TimeOfDay time) {
    _medication.scheduleTimes ??= [];
    if (!_medication.scheduleTimes!.contains(time)) {
      _medication.scheduleTimes!.add(time);
      // Sort times
      _medication.scheduleTimes!.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
      notifyListeners();
    }
  }

  // NEW: Remove a time from schedule
  void removeScheduleTime(TimeOfDay time) {
    _medication.scheduleTimes ??= [];
    _medication.scheduleTimes!.remove(time);
    notifyListeners();
  }

  void updateDuration(String duration) {
    _medication.duration = duration;
    notifyListeners();
  }

  // Page navigation
  void setCurrentPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  // Validate required fields
  List<String> validateMedication() {
    List<String> errors = [];

    if (_medication.medicationName == null ||
        _medication.medicationName!.isEmpty) {
      errors.add('Please enter a medication name');
    }
    if (_medication.dosage == null || _medication.dosage!.isEmpty) {
      errors.add('Please enter a dosage');
    }
    if (_medication.type == null || _medication.type!.isEmpty) {
      errors.add('Please select a medication type');
    }
    if (_medication.startDate == null) {
      errors.add('Please select a start date');
    }
    // CHANGED: Validate scheduleTimes instead of interval
    if (_medication.scheduleTimes == null ||
        _medication.scheduleTimes!.isEmpty) {
      errors.add('Please select at least one schedule time');
    }
    if (_medication.duration == null || _medication.duration!.isEmpty) {
      errors.add('Please select a duration');
    }

    return errors;
  }

  Future<bool> saveMedication() async {
    try {
      final validationError = validateMedication();
      if (validationError.isNotEmpty) {
        print('Validation error: $validationError');
        return false;
      }

      final user = await _authService.getCurrentUser(); // Added await
      if (user == null) {
        print('Error: No user logged in');
        return false;
      }

      if (isEditMode && _medicationId != null) {
        await _medicationService.updateMedication(
          _medicationId!,
          _medication,
          user.id,
        );
      } else {
        _medication.id = null;
        _medication.id = await _medicationService.addMedication(
          _medication,
          user.id,
        );
      }

      // ✅ Schedule notifications after save
      // await _scheduleNotificationsForMedication();

      return true;
    } catch (e) {
      print('Save medication error: $e');
      return false;
    }
  }

  // Reset form
  void resetForm() {
    _medication = MedicationModel(startDate: DateTime.now());
    _currentPage = 0;
    _medicationId = null;
    notifyListeners();
  }

  // Future<void> _scheduleNotificationsForMedication() async {
  //   if (_medication.scheduleTimes == null ||
  //       _medication.scheduleTimes!.isEmpty) {
  //     return;
  //   }

  //   final user = await _authService.getCurrentUser(); // Added await
  //   if (user == null) return;

  //   for (final time in _medication.scheduleTimes!) {
  //     final schedule = ScheduleNotificationModel(
  //       scheduleId:
  //           _medication.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
  //       medicineId: _medication.id!,
  //       medicineName: _medication.medicationName!,
  //       dosage: _medication.dosage!,
  //       time:
  //           '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
  //       startDate: _medication.startDate!,
  //       endDate: _parseDurationToEndDate(
  //         _medication.duration!,
  //         _medication.startDate!,
  //       ),
  //     );

  //     final result = await NotificationService.instance
  //         .scheduleNotificationsForSchedule(schedule);

  //     // ✅ Immediately send a test notification
  //     final testResult = await NotificationService.instance
  //         .scheduleTestNotification();
  //     if (testResult is NotificationSuccess) {
  //       print('✅ Test notification scheduled');
  //     } else if (testResult is NotificationError) {
  //       print('❌ Test notification failed: ${testResult.message}');
  //     }
  //     if (result is NotificationError) {
  //       print('Failed to schedule notification: ${result.message}');
  //     }
  //   }
  // }

  DateTime _parseDurationToEndDate(String duration, DateTime startDate) {
    final lower = duration.toLowerCase();

    if (lower == 'indefinitely') {
      return startDate.add(const Duration(days: 365 * 5)); // 5 years
    }

    final daysMatch = RegExp(r'(\d+)\s*days?').firstMatch(lower);
    if (daysMatch != null) {
      final days = int.tryParse(daysMatch.group(1)!) ?? 7;
      return startDate.add(Duration(days: days));
    }

    return startDate.add(const Duration(days: 7)); // fallback
  }
}
