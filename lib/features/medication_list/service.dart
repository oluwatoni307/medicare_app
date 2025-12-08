// ignore_for_file: unused_catch_clause
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart';
import '/data/models/log.dart';
import 'medicine_model.dart';

/// Service to fetch detailed medication information and its logs from local Hive storage.
/// This service uses a singleton pattern to ensure proper initialization.
class MedicationDetailService {
  // Singleton pattern
  static final MedicationDetailService _instance =
      MedicationDetailService._internal();
  factory MedicationDetailService() => _instance;
  MedicationDetailService._internal();

  late Box<Med> _medsBox;
  late Box<LogModel> _logsBox;
  bool _isInitialized = false;

  /// Check if the service is ready to use
  bool get isInitialized => _isInitialized;

  /// Initializes the service with Hive box references.
  /// This method is safe to call multiple times.
  ///
  /// Throws an exception if Hive hasn't been initialized or boxes can't be opened.
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('📦 MedicationDetailService already initialized');
      return;
    }

    try {
      debugPrint('📦 Initializing MedicationDetailService...');

      // Check if Hive is initialized
      if (!Hive.isAdapterRegistered(0)) {
        debugPrint('⚠️ Warning: Hive adapters may not be registered');
      }

      // Open or get existing boxes
      if (Hive.isBoxOpen('meds')) {
        _medsBox = Hive.box<Med>('meds');
        debugPrint('✅ Meds box already open, reusing');
      } else {
        _medsBox = await Hive.openBox<Med>('meds');
        debugPrint('✅ Meds box opened successfully');
      }

      if (Hive.isBoxOpen('logs')) {
        _logsBox = Hive.box<LogModel>('logs');
        debugPrint('✅ Logs box already open, reusing');
      } else {
        _logsBox = await Hive.openBox<LogModel>('logs');
        debugPrint('✅ Logs box opened successfully');
      }

      _isInitialized = true;
      debugPrint('✅ MedicationDetailService initialized successfully');
      debugPrint('   Meds count: ${_medsBox.length}');
      debugPrint('   Logs count: ${_logsBox.length}');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize MedicationDetailService: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false;
      rethrow; // Re-throw to let caller handle
    }
  }

  /// Fetches a medication and all its associated logs.
  ///
  /// [medicineId] The ID of the medication to fetch.
  ///
  /// Returns a [MedicationDetail] object containing the medication and its logs.
  /// Throws an exception if:
  /// - Service is not initialized
  /// - Medication is not found
  /// - Any other error occurs
  Future<MedicationDetail> getMedicineWithAllLogs(String medicineId) async {
    // Ensure service is initialized
    if (!_isInitialized) {
      throw Exception(
        'MedicationDetailService not initialized. Call init() first.',
      );
    }

    try {
      debugPrint('🔍 Fetching medication with ID: $medicineId');

      // 1. Fetch the medication from Hive
      Med? medication;
      try {
        medication = _medsBox.values.firstWhere((med) => med.id == medicineId);
        debugPrint('✅ Medication found: ${medication.name}');
      } on StateError {
        // More specific error when medication not found
        debugPrint('❌ Medication with ID $medicineId not found in box');
        throw MedicationNotFoundException(
          'Medication with ID $medicineId not found',
        );
      }

      // 2. Fetch all logs associated with this medication
      final List<LogModel> logs = [];
      int logCount = 0;

      for (final log in _logsBox.values) {
        if (log.medId == medicineId) {
          logs.add(log);
          logCount++;
        }
      }

      debugPrint('✅ Found $logCount logs for medication');

      // Sort logs by date (newest first) for better UX
      logs.sort((a, b) => b.date.compareTo(a.date));

      // 3. Package the data into the feature-specific model
      final detail = MedicationDetail(medication: medication, logs: logs);

      debugPrint('✅ MedicationDetail created successfully');
      return detail;
    } on MedicationNotFoundException {
      // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      // Handle any other unexpected errors
      debugPrint('❌ Failed to fetch medication details: $e');
      debugPrint('Stack trace: $stackTrace');
      throw MedicationDetailException('Failed to fetch medication details: $e');
    }
  }

  /// Gets a list of all medication IDs
  /// Useful for debugging or batch operations
  List<String> getAllMedicationIds() {
    if (!_isInitialized) {
      debugPrint('⚠️ Service not initialized, returning empty list');
      return [];
    }

    try {
      return _medsBox.values.map((med) => med.id).toList();
    } catch (e) {
      debugPrint('❌ Error getting medication IDs: $e');
      return [];
    }
  }

  /// Gets the count of logs for a specific medication
  /// Useful for quick checks without loading all logs
  int getLogCount(String medicineId) {
    if (!_isInitialized) {
      debugPrint('⚠️ Service not initialized');
      return 0;
    }

    try {
      return _logsBox.values.where((log) => log.medId == medicineId).length;
    } catch (e) {
      debugPrint('❌ Error getting log count: $e');
      return 0;
    }
  }

  /// Check if a medication exists
  bool medicationExists(String medicineId) {
    if (!_isInitialized) {
      debugPrint('⚠️ Service not initialized');
      return false;
    }

    try {
      return _medsBox.values.any((med) => med.id == medicineId);
    } catch (e) {
      debugPrint('❌ Error checking medication existence: $e');
      return false;
    }
  }

  /// Reset the service (useful for testing or cleanup)
  void reset() {
    _isInitialized = false;
    debugPrint('🔄 MedicationDetailService reset');
  }

  /// Close boxes (call this on app termination if needed)
  /// Note: Generally, Hive boxes should stay open for the app lifecycle
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      // Only close if we're the only ones using these boxes
      // In most apps, boxes should stay open
      debugPrint('⚠️ Disposing MedicationDetailService (boxes remain open)');
      _isInitialized = false;
    } catch (e) {
      debugPrint('❌ Error disposing service: $e');
    }
  }
}

/* -------------------------------------------------------------------------- */
/*                          CUSTOM EXCEPTIONS                                 */
/* -------------------------------------------------------------------------- */

/// Exception thrown when a medication is not found
class MedicationNotFoundException implements Exception {
  final String message;
  MedicationNotFoundException(this.message);

  @override
  String toString() => 'MedicationNotFoundException: $message';
}

/// Exception thrown when there's an error fetching medication details
class MedicationDetailException implements Exception {
  final String message;
  MedicationDetailException(this.message);

  @override
  String toString() => 'MedicationDetailException: $message';
}
