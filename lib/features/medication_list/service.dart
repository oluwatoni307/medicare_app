// /features/medication_detail/services/medication_detail_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart'; // Hive Med
import '/data/models/log.dart'; // Hive LogModel

import 'medicine_model.dart'; // For StateError

/// Service to fetch detailed medication information and its logs from local Hive storage.
class MedicationDetailService {
  late Box<Med> _medsBox;
  late Box<LogModel> _logsBox;

  /// Initializes the service with Hive box references.
  /// Must be called after Hive is initialized.
  Future<void> init() async {
    _medsBox = Hive.box<Med>('meds');
    _logsBox = Hive.box<LogModel>('logs');
  }

  /// Fetches a medication and all its associated logs.
  ///
  /// [medicineId] The ID of the medication to fetch.
  ///
  /// Returns a [MedicationDetail] object containing the medication and its logs.
  /// Throws an exception if the medication is not found.
  Future<MedicationDetail> getMedicineWithAllLogs(String medicineId) async {
    try {
      // 1. Fetch the medication from Hive
      final Med medication = _medsBox.values.firstWhere((med) => med.id == medicineId);
      // If not found, firstWhere throws StateError, which we let propagate
      // or catch and re-throw as a more specific error if desired.

      // 2. Fetch all logs associated with this medication from Hive
      final List<LogModel> logs = [];
      for (final log in _logsBox.values) {
        if (log.medId == medicineId) {
          logs.add(log);
        }
      }
      // Alternative using where (might be slightly less efficient in Hive context):
      // final logs = _logsBox.values.where((log) => log.medId == medicineId).toList();

      // 3. Package the data into the feature-specific model
      return MedicationDetail(
        medication: medication,
        logs: logs,
      );

    } on StateError catch (e) {
      // Handle the case where the medication is not found
      throw Exception('Medication with ID $medicineId not found.');
    } catch (e) {
      // Handle any other unexpected errors
      throw Exception('Failed to fetch medication details: $e');
    }
  }
}