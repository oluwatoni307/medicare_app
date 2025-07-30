import 'package:hive_flutter/hive_flutter.dart';
import './models/med.dart';
import './models/log.dart';
import './models/time_of_day_adapter.dart'; // Import TimeOfDay model

// Make sure you've generated these adapters!
// Run: flutter packages pub run build_runner build

Future<void> initHive() async {
  await Hive.initFlutter();

  // Register adapters (do this before opening boxes)
  Hive.registerAdapter(MedAdapter());
  Hive.registerAdapter(LogModelAdapter());
    Hive.registerAdapter(TimeOfDayAdapter()); // ✅ Add this


  // Open boxes using the correct types ✅
  await Hive.openBox<Med>('meds');     // Not MedAdapter!
  await Hive.openBox<LogModel>('logs');

  print("✅ Hive initialized: 'meds' and 'logs' boxes opened.");
}