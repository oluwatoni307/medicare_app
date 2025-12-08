import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart';

class MedicationListViewModel extends ChangeNotifier {
  List<Med> _medications = [];
  bool _isLoading = false;
  String? _errorMessage;
  late Box<Med> _medicationsBox;
  bool _isInitialized = false;

  /* ========== GETTERS ========== */

  List<Med> get medications => _medications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  /// Active medications: end_date is null or >= today (normalized to day)
  List<Med> get activeMedications =>
      _medications.where(_isMedicationActive).toList();

  /// Completed medications: end_date < today (normalized to day)
  List<Med> get completedMedications =>
      _medications.where((m) => !_isMedicationActive(m)).toList();

  /* ========== CONSTRUCTOR ========== */

  MedicationListViewModel() {
    _init();
  }

  /* ========== PRIVATE HELPERS ========== */

  /// Check if medication is active (FIXED: better date comparison)
  bool _isMedicationActive(Med medication) {
    if (medication.endAt == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = medication.endAt!;
    final endDateNormalized = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    // Active if end date is today or in the future
    return endDateNormalized.isAfter(today) ||
        endDateNormalized.isAtSameMomentAs(today);
  }

  /// Open Hive box safely (FIXED: check if already open)
  Future<void> _openBox() async {
    try {
      if (Hive.isBoxOpen('meds')) {
        _medicationsBox = Hive.box<Med>('meds');
        debugPrint('✅ Medications box already open, reusing');
      } else {
        _medicationsBox = await Hive.openBox<Med>('meds');
        debugPrint('✅ Medications box opened successfully');
      }
    } catch (e) {
      debugPrint('❌ Error opening medications box: $e');
      rethrow;
    }
  }

  /// Initialize the ViewModel
  Future<void> _init() async {
    try {
      await _openBox();
      _isInitialized = true;
      await loadMedications();
    } catch (e) {
      debugPrint('❌ Error initializing MedicationListViewModel: $e');
      _setError('Failed to initialize: $e');
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /* ========== CRUD OPERATIONS ========== */

  /// Load all medications from Hive
  Future<void> loadMedications() async {
    _setLoading(true);
    _setError(null);

    try {
      // Ensure box is open
      if (!_isInitialized) {
        await _init();
      }

      _medications = _medicationsBox.values.toList();
      debugPrint('✅ Loaded ${_medications.length} medications');
      debugPrint('   Active: ${activeMedications.length}');
      debugPrint('   Completed: ${completedMedications.length}');
    } catch (e) {
      debugPrint('❌ Load medications error: $e');
      _setError('Failed to load medications: $e');
      _medications = [];
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh medications (alias for loadMedications)
  Future<void> refreshMedications() => loadMedications();

  /// Add a new medication (OPTIMIZED: direct list update)
  Future<void> addMedication(Med medication) async {
    try {
      debugPrint('➕ Adding medication: ${medication.name}');

      await _medicationsBox.put(medication.id, medication);

      // Direct update instead of full reload
      _medications = _medicationsBox.values.toList();
      notifyListeners();

      debugPrint('✅ Medication added successfully');
    } catch (e) {
      debugPrint('❌ Add medication error: $e');
      _setError('Failed to add medication: $e');
      rethrow;
    }
  }

  /// Update an existing medication (OPTIMIZED: direct list update)
  Future<void> updateMedication(Med medication) async {
    try {
      debugPrint('✏️ Updating medication: ${medication.name}');

      await _medicationsBox.put(medication.id, medication);

      // Direct update instead of full reload
      _medications = _medicationsBox.values.toList();
      notifyListeners();

      debugPrint('✅ Medication updated successfully');
    } catch (e) {
      debugPrint('❌ Update medication error: $e');
      _setError('Failed to update medication: $e');
      rethrow;
    }
  }

  /// Delete a medication
  Future<void> deleteMedication(String medicationId) async {
    _setLoading(true);
    _setError(null);

    try {
      debugPrint('🗑️ Deleting medication with ID: $medicationId');

      await _medicationsBox.delete(medicationId);

      // Direct update instead of full reload
      _medications = _medicationsBox.values.toList();

      debugPrint('✅ Medication deleted successfully');
    } catch (e) {
      debugPrint('❌ Delete medication error: $e');
      _setError('Failed to delete medication: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /* ========== UTILITY METHODS ========== */

  /// Get medication by ID
  Med? getMedicationById(String id) {
    try {
      return _medications.firstWhere((med) => med.id == id);
    } catch (_) {
      debugPrint('⚠️ Medication with ID $id not found');
      return null;
    }
  }

  /// Search medications by name
  List<Med> searchMedications(String query) {
    if (query.isEmpty) return _medications;

    final q = query.toLowerCase();
    return _medications
        .where((med) => med.name.toLowerCase().contains(q))
        .toList();
  }

  /// Get count of active medications
  int get activeMedicationsCount => activeMedications.length;

  /// Get count of completed medications
  int get completedMedicationsCount => completedMedications.length;

  /// Check if a medication exists
  bool medicationExists(String id) {
    return _medications.any((med) => med.id == id);
  }

  /// Get medications that end soon (within next 7 days)
  List<Med> getMedicationsEndingSoon() {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));

    return activeMedications.where((med) {
      if (med.endAt == null) return false;
      return med.endAt!.isAfter(now) && med.endAt!.isBefore(sevenDaysLater);
    }).toList();
  }

  /// Get medications by type
  List<Med> getMedicationsByType(String type) {
    return _medications
        .where((med) => med.type.toLowerCase() == type.toLowerCase())
        .toList();
  }

  /* ========== LIFECYCLE ========== */

  /// Close the Hive box
  /// NOTE: In most cases, boxes should stay open for the app lifecycle.
  /// Only call this if you have a specific reason to close the box.
  Future<void> closeBox() async {
    try {
      if (_isInitialized && _medicationsBox.isOpen) {
        // Don't actually close - other parts of the app might be using it
        debugPrint('⚠️ Box close requested but keeping open for app lifecycle');
        // await _medicationsBox.close();
      }
    } catch (e) {
      debugPrint('❌ Error closing box: $e');
    }
  }

  @override
  void dispose() {
    // Don't close the box here - it's shared across the app
    debugPrint('🔄 MedicationListViewModel disposed');
    super.dispose();
  }
}
