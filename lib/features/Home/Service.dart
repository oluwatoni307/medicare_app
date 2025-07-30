import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart'; // Med with List<TimeOfDay> scheduleTimes
import '/data/models/log.dart'; // LogModel
import '../Home/Home_model.dart'; // HomepageData & MedicationInfo
import 'package:flutter/material.dart'; // For TimeOfDay

class DBhelper {
  static final DBhelper _instance = DBhelper._internal();
  
  // Hive boxes
  late Box<Med> _medsBox;
  late Box<LogModel> _logsBox;
    bool _isInitialized = false; // Track if init was called


  DBhelper._internal();

  factory DBhelper() => _instance;

  // Initialize Hive boxes - call this during app startup
  // This will be called automatically before any method runs
  Future<void> _initIfNotDone() async {
    if (_isInitialized) return;

    _medsBox = Hive.box<Med>('meds');
    _logsBox = Hive.box<LogModel>('logs');
    _isInitialized = true;

    print("✅ DBhelper: Ready! Meds box size: ${_medsBox.length}, Logs: ${_logsBox.length}");
  }
  // Get homepage data for a specific user
  Future<HomepageData> getHomepageData(String userId) async {
    _initIfNotDone();
    try {
      final upcomingMeds = await _getUpcomingMedicinesWithType(userId);
      final medications = upcomingMeds
          .map((med) => MedicationInfo.fromMap(med))
          .toList();

      return HomepageData(
        upcomingMedicationCount: medications.length,
        medications: medications,
      );
    } catch (e) {
      print('Error in getHomepageData: $e');
      return HomepageData.initial();
    }
  }

  // Get upcoming medicines with type from local Hive data
  Future<List<Map<String, dynamic>>> _getUpcomingMedicinesWithType(String userId) async {
    try {
      print("Fetching medicines for user: $userId (Local Hive)");
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      Set<String> uniqueMedicineIds = {};
      List<Map<String, dynamic>> result = [];
      
      for (final med in _medsBox.values) {
        // Check if medication is active today based on startAt and endAt dates
        if (_isMedicationActiveOnDate(med, today)) {
          if (!uniqueMedicineIds.contains(med.id)) {
            uniqueMedicineIds.add(med.id);
            result.add({
              'id': med.id,
              'name': med.name,
              'type': med.type,
            });
          }
        }
      }
      
      print('Transformed result with unique IDs: $result');
      return result;
    } catch (e) {
      print('Error fetching upcoming medicines: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUserMedicines(String userId) async {
    try {
      print("Fetching all medicines for user: $userId (Local Hive)");
      
      // Note: Hive Med model doesn't have user_id, so returning all meds
      final result = _medsBox.values.map((med) => {
        'id': med.id,
        'name': med.name,
        'type': med.type,
        'dosage': med.dosage,
      }).toList();
      
      print('All medicines response: $result');
      return result;
    } catch (e) {
      print('Error fetching all medicines: $e');
      rethrow;
    }
  }

  // Get medicines that need attention today (based on your plan)
  Future<List<Map<String, dynamic>>> getUpcomingMedicines(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentTimeOfDay = TimeOfDay.fromDateTime(now); // Current time
      
      final result = <Map<String, dynamic>>[];
      
      for (final med in _medsBox.values) {
        // 1. Check if medication is active today based on date range
        if (_isMedicationActiveOnDate(med, today)) {
          // 2. Find existing log for this medicine and today
          LogModel? existingLog;
          try {
            existingLog = _logsBox.values.firstWhere((log) => 
              log.medId == med.id && 
              _isSameDay(log.date, today)
            );
          } catch (e) {
            // No log found for this med today
          }
          
          // 3. If no log exists, the medicine needs attention (per your plan)
          //    If log exists but percent < 100, it also needs attention
          if (existingLog == null || existingLog.percent < 100.0) {
            // Determine status message based on time of day and schedule
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
              'time': statusMessage, // General status, not specific time
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
      print('Error fetching upcoming medicines: $e');
      rethrow;
    }
  }

  // Get completed medicines for today (100% completed)
  Future<List<Map<String, dynamic>>> getCompletedMedicines(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final result = <Map<String, dynamic>>[];
      
      for (final med in _medsBox.values) {
        // 1. Check if medication is active today based on date range
        if (_isMedicationActiveOnDate(med, today)) {
          // 2. Find existing log for this medicine and today
          LogModel? existingLog;
          try {
            existingLog = _logsBox.values.firstWhere((log) => 
              log.medId == med.id && 
              _isSameDay(log.date, today)
            );
          } catch (e) {
            // No log found for this med today
          }
          
          // 3. If log exists and percent is 100, it's completed
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
          // If no log or percent < 100, it's not completed
        }
      }

      return result;
    } catch (e) {
      print('Error fetching completed medicines: $e');
      rethrow;
    }
  }

  // Helper method to check if a medication is active on a specific date
  // This only checks the date range (startAt to endAt), not specific times of day
  bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
    // Check if targetDate is within the medication's active period
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
    
    // If we passed the above checks, the medication is active on this date
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
    print('Local Hive database is ready');
  }
}

// Extension to format TimeOfDay (if not already defined globally)
extension TimeOfDayExtension on TimeOfDay {
  String formatTime() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}