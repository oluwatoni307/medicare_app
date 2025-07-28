import 'package:hive_flutter/hive_flutter.dart';
import './models/med.dart';
import './models/log.dart';

Future<void> initHive() async {
  await Hive.initFlutter();
  
  // Register adapters
  Hive.registerAdapter(MedAdapter());
  Hive.registerAdapter(LogModelAdapter());
  
  // Open boxes
  await Hive.openBox<MedAdapter>('meds');
  await Hive.openBox<LogModel>('logs');
}