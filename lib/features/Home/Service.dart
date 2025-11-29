import 'package:hive_flutter/hive_flutter.dart';
import '/data/models/med.dart';
import '/data/models/log.dart';
import '../Home/Home_model.dart';
import 'package:flutter/material.dart';

class DBhelper {
  static final DBhelper _instance = DBhelper._internal();
  
  Box<Med>? _medsBox;
  Box<LogModel>? _logsBox;
  bool _isInitialized = false;

  DBhelper._internal();

  factory DBhelper() => _instance;

  Future<void> _initIfNotDone() async {
    if (_isInitialized) return;

    try {
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

  Future<void> initialize() async {
    await _initIfNotDone();
  }

  /// Get homepage data with enriched adherence status
  Future<HomepageData> getHomepageData(String userId) async {
    await _initIfNotDone();
    
    try {
      final enrichedMeds = await _getEnrichedMedicationsWithStatus(userId);
      final medications = enrichedMeds
          .map((med) => MedicationInfo.fromMap(med))
          .toList();

      final summary = await getTodaysSummary(userId);

      final result = HomepageData(
        upcomingMedicationCount: medications.length,
        medications: medications,
        todaysSummary: summary,
      );

      print("📊 Homepage data loaded: ${medications.length} medications");
      return result;
    } catch (e) {
      print('❌ Error in getHomepageData: $e');
      return HomepageData.initial();
    }
  }

  /// Get ALL active medications with today's adherence status
  Future<List<Map<String, dynamic>>> _getEnrichedMedicationsWithStatus(String userId) async {
    try {
      if (_medsBox == null || _logsBox == null) {
        print("❌ Boxes are null!");
        return [];
      }

      print("📋 Fetching active medications with status");
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      Set<String> uniqueMedicineIds = {};
      List<Map<String, dynamic>> result = [];
      
      for (final med in _medsBox!.values) {
        // Check if medication is active (not ended)
        if (_isMedicationActiveOnDate(med, today) && !uniqueMedicineIds.contains(med.id)) {
          uniqueMedicineIds.add(med.id);
          
          // Get today's log for this medication
          LogModel? todaysLog;
          try {
            todaysLog = _logsBox!.values.firstWhere(
              (log) => log.medId == med.id && _isSameDay(log.date, today)
            );
          } catch (e) {
            // No log for today
          }

          // Calculate adherence data
          final totalDoses = med.scheduleTimes.length;
          int takenDoses = 0;
          double adherencePercent = 0.0;
          bool hasScheduleToday = totalDoses > 0;
          bool isCompleteToday = false;

          if (todaysLog != null && todaysLog.percent != 0.1) {
            // Real log exists (not 0.1% sentinel)
            takenDoses = todaysLog.takenScheduleIndices.where((i) => i == 1).length;
            adherencePercent = todaysLog.percent;
            isCompleteToday = adherencePercent >= 100.0;
          }

          result.add({
            'id': med.id,
            'name': med.name,
            'type': med.type,
            'takenDoses': takenDoses,
            'totalDoses': totalDoses,
            'adherencePercent': adherencePercent,
            'hasScheduleToday': hasScheduleToday,
            'isCompleteToday': isCompleteToday,
          });
          
          print("✅ Added: ${med.name} - $takenDoses/$totalDoses doses");
        }
      }
      
      print('📊 Final result: ${result.length} active medications');
      return result;
    } catch (e) {
      print('❌ Error fetching medications: $e');
      rethrow;
    }
  }

  /// Get today's summary across all medications
  Future<TodaysSummary?> getTodaysSummary(String userId) async {
    await _initIfNotDone();
    
    try {
      if (_medsBox == null || _logsBox == null) {
        return null;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      int totalDoses = 0;
      int takenDoses = 0;
      String? nextDoseInfo;
      TimeOfDay? earliestNextDose;
      String? nextDoseMedication;

      for (final med in _medsBox!.values) {
        if (!_isMedicationActiveOnDate(med, today)) continue;

        totalDoses += med.scheduleTimes.length;

        // Get today's log
        LogModel? todaysLog;
        try {
          todaysLog = _logsBox!.values.firstWhere(
            (log) => log.medId == med.id && _isSameDay(log.date, today)
          );
        } catch (e) {
          // No log
        }

        if (todaysLog != null && todaysLog.percent != 0.1) {
          takenDoses += todaysLog.takenScheduleIndices.where((i) => i == 1).length;
        }

        // Find next dose time
        final currentTime = TimeOfDay.now();
        for (final scheduleTime in med.scheduleTimes) {
          if (_isTimeOfDayAfter(scheduleTime, currentTime)) {
            if (earliestNextDose == null || _isTimeOfDayBefore(scheduleTime, earliestNextDose)) {
              earliestNextDose = scheduleTime;
              nextDoseMedication = med.name;
            }
          }
        }
      }

      if (totalDoses == 0) {
        return null; // No doses scheduled today
      }

      if (earliestNextDose != null && nextDoseMedication != null) {
        nextDoseInfo = '$nextDoseMedication at ${_formatTimeOfDay(earliestNextDose)}';
      }

      final overallPercent = (takenDoses / totalDoses) * 100;

      return TodaysSummary(
        totalDoses: totalDoses,
        takenDoses: takenDoses,
        overallPercent: overallPercent,
        nextDoseInfo: nextDoseInfo,
      );
    } catch (e) {
      print('❌ Error getting today\'s summary: $e');
      return null;
    }
  }

  // Keep existing methods for backward compatibility
  Future<List<Map<String, dynamic>>> getAllUserMedicines(String userId) async {
    await _initIfNotDone();
    
    try {
      if (_medsBox == null) {
        return [];
      }

      final result = _medsBox!.values.map((med) => {
        'id': med.id,
        'name': med.name,
        'type': med.type,
        'dosage': med.dosage,
      }).toList();
      
      return result;
    } catch (e) {
      print('❌ Error fetching all medicines: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingMedicines(String userId) async {
    await _initIfNotDone();
    
    try {
      if (_medsBox == null || _logsBox == null) {
        return [];
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentTimeOfDay = TimeOfDay.fromDateTime(now);
      
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
            // No log
          }
          
          if (existingLog == null || existingLog.percent < 100.0) {
            String statusMessage = 'Scheduled for today';
            
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

  Future<List<Map<String, dynamic>>> getCompletedMedicines(String userId) async {
    await _initIfNotDone();
    
    try {
      if (_medsBox == null || _logsBox == null) {
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
            // No log
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

  // Helper methods
  bool _isMedicationActiveOnDate(Med med, DateTime targetDate) {
    final startDate = DateTime(med.startAt.year, med.startAt.month, med.startAt.day);
    
    if (startDate.isAfter(targetDate)) {
      return false;
    }
    
    if (med.endAt != null) {
      final endDate = DateTime(med.endAt!.year, med.endAt!.month, med.endAt!.day);
      if (endDate.isBefore(targetDate)) {
        return false;
      }
    }
    
    return true;
  }

  bool _isTimeOfDayBefore(TimeOfDay a, TimeOfDay b) {
    if (a.hour < b.hour) return true;
    if (a.hour > b.hour) return false;
    return a.minute < b.minute;
  }

  bool _isTimeOfDayAfter(TimeOfDay a, TimeOfDay b) {
    if (a.hour > b.hour) return true;
    if (a.hour < b.hour) return false;
    return a.minute > b.minute;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> testDatabase() async {
    await _initIfNotDone();
    print('🔧 Local Hive database is ready');
    print('📊 Meds box size: ${_medsBox?.length ?? 0}');
    print('📊 Logs box size: ${_logsBox?.length ?? 0}');
  }

  bool get isInitialized => _isInitialized && _medsBox != null && _logsBox != null;
}