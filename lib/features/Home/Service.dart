import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart'; // Med with List<TimeOfDay> scheduleTimes
import '/data/models/log.dart'; // LogModel
import '../Home/Home_model.dart'; // HomepageData & MedicationInfo
import 'package:flutter/material.dart'; // For TimeOfDay

class DBhelper {
  static final DBhelper _instance = DBhelper._internal();
  
  // Hive boxes
  Box<Med>? _medsBox;
  Box<LogModel>? _logsBox;
  bool _isInitialized = false; // Track if init was called

  DBhelper._internal();

  factory DBhelper() => _instance;

  // Initialize Hive boxes - call this during app startup
  Future<void> _initIfNotDone() async {
    if (_isInitialized) return;

    try {
      // Ensure Hive is initialized first
      if (!Hive.isBoxOpen('meds')) {
        _medsBox = await Hive.openBox<Med>('meds');
      } else {
        _medsBox = Hive.box<Med>('meds');
      }

      if (!Hive.isBoxOpen('logs')) {
        _logsBox = await Hive.openBox<LogModel>('logs');
      } else {
        _logsBox = Hive.box<LogModel>('logs');
      }

      _isInitialized = true;
      print("✅ DBhelper: Ready! Meds box size: ${_medsBox!.length}, Logs: ${_logsBox!.length}");
    } catch (e) {
      print("❌ DBhelper initialization failed: $e");
      rethrow;
    }
  }

  // Public method to ensure initialization (call this from main.dart)
  Future<void> initialize() async {
    await _initIfNotDone();
  }

  // Get homepage data for a specific user
  Future<HomepageData> getHomepageData(String userId) async {
    await _initIfNotDone(); // ✅ Properly await initialization
    
    try {
      final upcomingMeds = await _getUpcomingMedicinesWithType(userId);
      final medications = upcomingMeds
          .map((med) => MedicationInfo.fromMap(med))
          .toList();

      final result = HomepageData(
        upcomingMedicationCount: medications.length,
        medications: medications,
      );

      print("📊 Homepage data loaded: ${medications.length} medications");
      return result;
    } catch (e) {
      print('❌ Error in getHomepageData: $e');
      return HomepageData.initial();
    }
  }

  // Get upcoming medicines with type from local Hive data
  Future<List<Map<String, dynamic>>> _getUpcomingMedicinesWithType(String userId) async {
    try {
      if (_medsBox == null) {
        print("❌ Meds box is null!");
        return [];
      }

      print("📋 Fetching medicines for user: $userId (Local Hive)");
      print("📦 Total medicines in box: ${_medsBox!.length}");
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      Set<String> uniqueMedicineIds = {};
      List<Map<String, dynamic>> result = [];
      
      for (final med in _medsBox!.values) {
        print("🔍 Checking medicine: ${med.name} (ID: ${med.id})");
        
        // Check if medication is active today based on startAt and endAt dates
        if (_isMedicationActiveOnDate(med, today)) {
          if (!uniqueMedicineIds.contains(med.id)) {
            uniqueMedicineIds.add(med.id);
            result.add({
              'id': med.id,
              'name': med.name,
              'type': med.type,
            });
            print("✅ Added medicine: ${med.name}");
          } else {
            print("⏭️  Skipped duplicate: ${med.name}");
          }
        } else {
          print("❌ Medicine not active today: ${med.name}");
        }
      }
      
      print('📊 Final result with unique IDs: $result');
      return result;
    } catch (e) {
      print('❌ Error fetching upcoming medicines: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUserMedicines(String userId) async {
    await _initIfNotDone(); // Ensure initialization
    
    try {
      if (_medsBox == null) {
        print("❌ Meds box is null!");
        return [];
      }

      print("📋 Fetching all medicines for user: $userId (Local Hive)");
      
      // Note: Hive Med model doesn't have user_id, so returning all meds
      final result = _medsBox!.values.map((med) => {
        'id': med.id,
        'name': med.name,
        'type': med.type,
        'dosage': med.dosage,
      }).toList();
      
      print('📊 All medicines response: $result');
      return result;
    } catch (e) {
      print('❌ Error fetching all medicines: $e');
      rethrow;
    }
  }

  // Get medicines that need attention today (based on your plan)
  Future<List<Map<String, dynamic>>> getUpcomingMedicines(String userId) async {
    await _initIfNotDone(); // Ensure initialization
    
    try {
      if (_medsBox == null || _logsBox == null) {
        print("❌ Boxes are null!");
        return [];
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentTimeOfDay = TimeOfDay.fromDateTime(now);
      
      final result = <Map<String, dynamic>>[];
      
      for (final med in _medsBox!.values) {
        // 1. Check if medication is active today based on date range
        if (_isMedicationActiveOnDate(med, today)) {
          // 2. Find existing log for this medicine and today
          LogModel? existingLog;
          try {
            existingLog = _logsBox!.values.firstWhere((log) => 
              log.medId == med.id && 
              _isSameDay(log.date, today)
            );
          } catch (e) {
            // No log found for this med today
          }
          
          // 3. If no log exists, the medicine needs attention
          if (existingLog == null || existingLog.percent < 100.0) {
            String statusMessage = 'Scheduled for today';
            
            // Check if any scheduled times have passed
            bool hasPastTimes = med.scheduleTimes.any((scheduledTime) => 
              _isTimeOfDayBefore(scheduledTime, currentTimeOfDay)
            );
            
            if (hasPastTimes) {
              statusMessage = 'Dose time passed';
            } else {
              statusMessage = 'Scheduled for later';
            }

            result.add({
              'id': med.id,
              'time': statusMessage,
              'medicines': {
                'name': med.name,
                'dosage': med.dosage,
              },
              'logs': {
                'percent': existingLog?.percent ?? 0.0,
              }
            });
          }
        }
      }

      return result;
    } catch (e) {
      print('❌ Error fetching upcoming medicines: $e');
      rethrow;
    }
  }

  // Get completed medicines for today (100% completed)
  Future<List<Map<String, dynamic>>> getCompletedMedicines(String userId) async {
    await _initIfNotDone(); // Ensure initialization
    
    try {
      if (_medsBox == null || _logsBox == null) {
        print("❌ Boxes are null!");
        return [];
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final result = <Map<String, dynamic>>[];
      
      for (final med in _medsBox!.values) {
        if (_isMedicationActiveOnDate(med, today)) {
          LogModel? existingLog;
          try {
            existingLog = _logsBox!.values.firstWhere((log) => 
              log.medId == med.id && 
              _isSameDay(log.date, today)
            );
          } catch (e) {
            // No log found for this med today
          }
          
          if (existingLog != null && existingLog.percent >= 100.0) {
            result.add({
              'id': med.id,
              'time': 'Completed Today',
              'medicines': {
                'name': med.name,
                'dosage': med.dosage,
              },
              'logs': {
                'status': 'taken',
                'date': today.toIso8601String().split('T')[0],
                'percent': existingLog.percent,
              }
            });
          }
        }
      }

      return result;
    } catch (e) {
      print('❌ Error fetching completed medicines: $e');
      rethrow;
    }
  }

  // Helper method to check if a medication is active on a specific date
  bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
    final startDate = DateTime(med.startAt.year, med.startAt.month, med.startAt.day);
    
    if (startDate.isAfter(targetDate)) {
      return false; // Not started yet
    }
    
    if (med.endAt != null) {
      final endDate = DateTime(med.endAt!.year, med.endAt!.month, med.endAt!.day);
      if (endDate.isBefore(targetDate)) {
        return false; // Already ended
      }
    }
    
    return true;
  }

  // Helper method to check if TimeOfDay a is before TimeOfDay b
  bool _isTimeOfDayBefore(TimeOfDay a, TimeOfDay b) {
    if (a.hour < b.hour) return true;
    if (a.hour > b.hour) return false;
    return a.minute < b.minute;
  }

  // Helper method to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  Future<void> testDatabase() async {
    await _initIfNotDone();
    print('🔧 Local Hive database is ready');
    print('📊 Meds box size: ${_medsBox?.length ?? 0}');
    print('📊 Logs box size: ${_logsBox?.length ?? 0}');
  }

  // Method to check if boxes are properly initialized
  bool get isInitialized => _isInitialized && _medsBox != null && _logsBox != null;
}

// Extension to format TimeOfDay (if not already defined globally)
extension TimeOfDayExtension on TimeOfDay {
  String formatTime() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}