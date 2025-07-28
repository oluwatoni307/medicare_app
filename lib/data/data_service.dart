// import 'package:medicare_app/data/models/log.dart';
// import 'package:medicare_app/data/models/med.dart';
// import 'package:medicare_app/data/repository.dart';

// class DataService {
//   static final DataService _instance = DataService._internal();
//   factory DataService() => _instance;
//   DataService._internal();

//   List<TodayMed>? _todayMeds;
  
//   LocalRepository get _repo => LocalRepository();
  
//   // Initialize once when app starts
//   void initialize() {
//     _todayMeds = _repo.getTodayMeds();
//   }
  
//   // Access the pre-loaded list
//   List<TodayMed> get todayMeds {
//     return _todayMeds ?? [];
//   }
  
//   // Refresh when needed (after updates)
//   void refreshTodayMeds() {
//     _todayMeds = _repo.getTodayMeds();
//   }
  
//   // Other methods
//   List<Log> getAllLogs() => _repo.getAllLogs();
//   List<Log> getLogsForMed(String medId) => _repo.getLogsForMed(medId);
//   Future<void> saveMed(Med med) async {
//     await _repo.saveMed(med);
//     refreshTodayMeds(); // Auto-refresh after save
//   }
  
//   Future<void> saveLog(Log log) async {
//     await _repo.saveLog(log);
//     refreshTodayMeds(); // Auto-refresh after save
//   }
// }