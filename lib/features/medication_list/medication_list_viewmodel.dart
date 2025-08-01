// medication_list_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart'; // Hive Med with List<TimeOfDay> scheduleTimes

class MedicationListViewModel extends ChangeNotifier {
  List<Med> _medications = [];
  bool _isLoading = false;
  late Box<Med> _medicationsBox;

  List<Med> get medications => _medications;
  bool get isLoading => _isLoading;

  // Active = end_date >= today or no end date
  List<Med> get activeMedications => _medications.where(_isMedicationActive).toList();

  // Completed = end_date < today
  List<Med> get completedMedications => _medications.where((m) => !_isMedicationActive(m)).toList();

  bool _isMedicationActive(Med medication) {
    if (medication.endAt == null) return true;
    
    final today = DateTime.now();
    final endDate = medication.endAt!;
    return endDate.isAfter(today) || endDate.isAtSameMomentAs(today);
  }

  MedicationListViewModel() {
    _init();
  }

  Future<void> _init() async {
    await _openBox();
    await loadMedications();
  }

  Future<void> _openBox() async {
    _medicationsBox = await Hive.openBox<Med>('medications');
  }

  Future<void> loadMedications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _medications = _medicationsBox.values.toList();
    } catch (e) {
      print('Load medications error: $e');
      _medications = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshMedications() async {
    await loadMedications();
  }

  // Add new medication
  Future<void> addMedication(Med medication) async {
    try {
      await _medicationsBox.put(medication.id, medication);
      await loadMedications();
    } catch (e) {
      print('Add medication error: $e');
    }
  }

  // Update existing medication
  Future<void> updateMedication(Med medication) async {
    try {
      await _medicationsBox.put(medication.id, medication);
      await loadMedications();
    } catch (e) {
      print('Update medication error: $e');
    }
  }

  // Delete medication
  Future<void> deleteMedication(String medicationId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _medicationsBox.delete(medicationId);
      await loadMedications();
    } catch (e) {
      print('Delete medication error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Med? getMedicationById(String id) {
    try {
      return _medications.firstWhere((med) => med.id == id);
    } catch (e) {
      return null;
    }
  }

  // Search medications
  List<Med> searchMedications(String query) {
    final queryLower = query.toLowerCase();
    return _medications.where((med) {
      final name = med.name.toLowerCase();
      return name.contains(queryLower);
    }).toList();
  }

  // Close box when done (optional, for cleanup)
  Future<void> closeBox() async {
    await _medicationsBox.close();
  }
}