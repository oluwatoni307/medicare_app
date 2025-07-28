// /features/medication_detail/models/medication_detail.dart
import '/data/models/med.dart'; // Import Hive Med
import '/data/models/log.dart'; // Import Hive LogModel (the one with takenScheduleIndices)

/// A model to hold medication details and its associated logs for the detail view.
class MedicationDetail {
  /// The core medication information.
  final Med medication;

  /// All log entries associated with this medication.
  /// These are the Hive LogModel objects containing daily percent and taken indices.
  final List<LogModel> logs;

  MedicationDetail({
    required this.medication,
    required this.logs,
  });

  // You can add convenient getters here if needed, for example:
  // String get name => medication.name;
  // String get dosage => medication.dosage;
  // DateTime get startDate => medication.startAt;
  // DateTime? get endDate => medication.endAt;
  // List<TimeOfDay> get scheduleTimes => medication.scheduleTimes;
}