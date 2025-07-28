// import 'package:hive/hive.dart';
// import './models/med.dart';
// import './models/log.dart';

// abstract class MedicationRepository {
//   Future<List<MedicationModel>> getAllMedications();
//   Future<MedicationModel?> getMedicationById(String id);
//   Future<void> addMedication(MedicationModel medication);
//   Future<void> updateMedication(MedicationModel medication);
//   Future<void> deleteMedication(String id);
  
//   Future<List<LogModel>> getLogsByMedId(String medId);
//   Future<void> addLog(LogModel log);
//   Future<void> updateLog(LogModel log);
// }

// class HiveMedicationRepository implements MedicationRepository {
//   late Box<MedicationModel> _medsBox;
//   late Box<LogModel> _logsBox;

//   Future<void> init() async {
//     _medsBox = Hive.box<MedicationModel>('meds');
//     _logsBox = Hive.box<LogModel>('logs');
//   }

//   @override
//   Future<List<MedicationModel>> getAllMedications() async {
//     return _medsBox.values.toList();
//   }

//   @override
//   Future<MedicationModel?> getMedicationById(String id) async {
//     try {
//       return _medsBox.values.firstWhere((med) => med.id == id);
//     } catch (e) {
//       return null;
//     }
//   }

//   @override
//   Future<void> addMedication(MedicationModel medication) async {
//     await _medsBox.add(medication);
//   }

//   @override
//   Future<void> updateMedication(MedicationModel medication) async {
//     await medication.save();
//   }

//   @override
//   Future<void> deleteMedication(String id) async {
//     final med = await getMedicationById(id);
//     if (med != null) {
//       await med.delete();
//     }
//   }

//   @override
//   Future<List<LogModel>> getLogsByMedId(String medId) async {
//     return _logsBox.values
//         .where((log) => log.medId == medId)
//         .toList();
//   }

//   @override
//   Future<void> addLog(LogModel log) async {
//     await _logsBox.add(log);
//   }

//   @override
//   Future<void> updateLog(LogModel log) async {
//     await log.save();
//   }
// }