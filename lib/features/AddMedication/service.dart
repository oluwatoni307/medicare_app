import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart'; // Your updated Hive Med model
import '/data/models/log.dart';
import 'AddMedication_model.dart';

class MedicationService {
  late Box<Med> _medsBox;
  late Box<LogModel> _logsBox;

  bool _isInitialized = false;

  // Add this method
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    _medsBox = Hive.box<Med>('meds');
    _logsBox = Hive.box<LogModel>('logs');
    _isInitialized = true;
  }

  /* ---------- CREATE ---------- */
  Future<void> addMedication(MedicationModel med, String userId) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    try {
      final hiveMed = Med(
        id: med.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: med.medicationName ?? '',
        dosage: med.dosage ?? '',
        type: med.type ?? '',
        scheduleTimes: med.scheduleTimes ?? [], // Direct mapping - no conversion needed!
        startAt: med.startDate!,
        endAt: _calculateEndDate(med.startDate!, med.duration),
      );

      await _medsBox.add(hiveMed);
    } catch (e) {
      throw Exception('Add medication error: $e');
    }
  }

  /* ---------- READ ---------- */
  Future<List<MedicationModel>> getMedications(String userId) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    try {
      final hiveMeds = _medsBox.values.toList();
      return hiveMeds.map((hiveMed) => _convertHiveMedToModel(hiveMed)).toList();
    } catch (e) {
      throw Exception('Get medications error: $e');
    }
  }

  /* ---------- UPDATE ---------- */
  Future<void> updateMedication(String id, MedicationModel med) async {
    await _ensureInitialized(); // Ensure boxes are initialized
    try {
      // Find and update the medication
      for (int i = 0; i < _medsBox.length; i++) {
        final existingMed = _medsBox.getAt(i);
        if (existingMed?.id == id) {
          final updatedMed = Med(
            id: existingMed!.id,
            name: med.medicationName ?? existingMed.name,
            dosage: med.dosage ?? existingMed.dosage,
            type: med.type ?? existingMed.type,
            scheduleTimes: med.scheduleTimes ?? [], // Direct mapping
            startAt: med.startDate!,
            endAt: _calculateEndDate(med.startDate!, med.duration),
          );

          await _medsBox.putAt(i, updatedMed);
          break;
        }
      }
    } catch (e) {
      throw Exception('Update medication error: $e');
    }
  }

  /* ---------- DELETE ---------- */
  Future<void> deleteMedication(String id) async {
        await _ensureInitialized(); // Ensure boxes are initialized

    try {
      for (int i = 0; i < _medsBox.length; i++) {
        final med = _medsBox.getAt(i);
        if (med?.id == id) {
          await _medsBox.deleteAt(i);
          break;
        }
      }
    } catch (e) {
      throw Exception('Delete medication error: $e');
    }
  }

  /* ---------- LOG METHODS ---------- */
  // Future<void> addLog(String medId, DateTime date, double percent) async {
  //   try {
  //     final log = LogModel(
  //       medId: medId,
  //       date: date,
  //       percent: percent,
  //     );
  //     await _logsBox.add(log);
  //   } catch (e) {
  //     throw Exception('Add log error: $e');
  //   }
  // }

  Future<List<LogModel>> getLogsByMedId(String medId) async {
        await _ensureInitialized(); // Ensure boxes are initialized

    try {
      return _logsBox.values
          .where((log) => log.medId == medId)
          .toList();
    } catch (e) {
      throw Exception('Get logs error: $e');
    }
  }

  /* ---------- HELPER METHODS ---------- */
  
  // Calculate end date from duration string
  DateTime? _calculateEndDate(DateTime startDate, String? duration) {
    
    if (duration == null || duration == 'indefinitely') {
      return null;
    }

    final parts = duration.split(' ');
    if (parts.length >= 2) {
      final number = int.tryParse(parts[0]);
      if (number != null) {
        if (duration.contains('day')) {
          return startDate.add(Duration(days: number));
        } else if (duration.contains('week')) {
          return startDate.add(Duration(days: number * 7));
        } else if (duration.contains('month')) {
          return DateTime(startDate.year, startDate.month + number, startDate.day);
        } else if (duration.contains('year')) {
          return DateTime(startDate.year + number, startDate.month, startDate.day);
        }
      }
    }
    
    return startDate.add(const Duration(days: 7)); // Default 7 days
  }

  // Convert Hive Med back to MedicationModel
  MedicationModel _convertHiveMedToModel(Med hiveMed) {
    return MedicationModel(
      id: hiveMed.id,
      medicationName: hiveMed.name,
      dosage: hiveMed.dosage,
      type: hiveMed.type,
      startDate: hiveMed.startAt,
      scheduleTimes: hiveMed.scheduleTimes, // Direct mapping
      duration: hiveMed.endAt == null 
          ? 'indefinitely' 
          : '${hiveMed.startAt.difference(hiveMed.endAt!).inDays.abs()} days',
    );
  }
}