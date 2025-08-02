// medication_list_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart';

class MedicationListViewModel extends ChangeNotifier {
  List<Med> _medications = [];
  bool _isLoading = false;
  late Box<Med> _medicationsBox;

  /* ---------- getters ---------- */
  List<Med> get medications => _medications;
  bool get isLoading => _isLoading;

  // Active = end_date is null or >= today
  List<Med> get activeMedications =>
      _medications.where(_isMedicationActive).toList();

  // Completed = end_date < today
  List<Med> get completedMedications =>
      _medications.where((m) => !_isMedicationActive(m)).toList();

  /* ---------- constructor ---------- */
  MedicationListViewModel() {
    _init();
  }

  /* ---------- private helpers ---------- */
  bool _isMedicationActive(Med medication) {
    if (medication.endAt == null) return true;
    final today = DateTime.now();
    final endDate = medication.endAt!;
    return !endDate.isBefore(today);
  }

  Future<void> _openBox() async {
    _medicationsBox = await Hive.openBox<Med>('meds');
  }

  Future<void> _init() async {
    await _openBox();
    await loadMedications();
  }

  /* ---------- CRUD operations ---------- */
  Future<void> loadMedications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _medications = _medicationsBox.values.toList();
    } catch (e) {
      debugPrint('Load medications error: $e');
      _medications = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshMedications() => loadMedications();

  Future<void> addMedication(Med medication) async {
    try {
      await _medicationsBox.put(medication.id, medication);
      await loadMedications();
    } catch (e) {
      debugPrint('Add medication error: $e');
    }
  }

  Future<void> updateMedication(Med medication) async {
    try {
      await _medicationsBox.put(medication.id, medication);
      await loadMedications();
    } catch (e) {
      debugPrint('Update medication error: $e');
    }
  }

  Future<void> deleteMedication(String medicationId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _medicationsBox.delete(medicationId);
      await loadMedications();
    } catch (e) {
      debugPrint('Delete medication error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /* ---------- utilities ---------- */
  Med? getMedicationById(String id) {
    try {
      return _medications.firstWhere((med) => med.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Med> searchMedications(String query) {
    final q = query.toLowerCase();
    return _medications
        .where((med) => med.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> closeBox() => _medicationsBox.close();
}