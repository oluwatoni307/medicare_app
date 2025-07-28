import 'package:flutter/material.dart';

class LogModel {
  final String id;
  final String scheduleId;
  final String date;
  final LogStatus status;
  final DateTime createdAt;

  LogModel({
    required this.id,
    required this.scheduleId,
    required this.date,
    required this.status,
    required this.createdAt,
  });

  factory LogModel.fromJson(Map<String, dynamic> json) {
    return LogModel(
      id: json['id'],
      scheduleId: json['schedule_id'],
      date: json['date'],
      status: LogStatus.fromString(json['status']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'schedule_id': scheduleId,
      'date': date,
      'status': status.value,
    };
  }

  @override
  String toString() {
    return 'LogModel(id: $id, scheduleId: $scheduleId, date: $date, status: $status)';
  }
}

enum LogStatus {
  taken('taken'),
  missed('missed');

  const LogStatus(this.value);
  final String value;

  static LogStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'taken':
        return LogStatus.taken;
      case 'missed':
        return LogStatus.missed;
      default:
        throw ArgumentError('Invalid log status: $value');
    }
  }

  @override
  String toString() => value;
}

class ScheduleLogModel {
  final String id;
  final String medicineId;
  final String time;
  final String startDate;
  final String endDate;
  final DateTime createdAt;

  ScheduleLogModel({
    required this.id,
    required this.medicineId,
    required this.time,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory ScheduleLogModel.fromJson(Map<String, dynamic> json) {
    return ScheduleLogModel(
      id: json['id'],
      medicineId: json['medicine_id'],
      time: json['time'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // Helper method to get display name for schedule
  String get displayName {
    final timeOfDay = _parseTimeOfDay(time);
    if (timeOfDay != null) {
      final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
      final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
      final minute = timeOfDay.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    }
    return time; // fallback to original time string
  }

  // Helper method to get schedule label (Morning, Afternoon, Evening)
  String get scheduleLabel {
    final timeOfDay = _parseTimeOfDay(time);
    if (timeOfDay != null) {
      final hour = timeOfDay.hour;
      if (hour < 12) {
        return 'Morning';
      } else if (hour < 17) {
        return 'Afternoon';
      } else {
        return 'Evening';
      }
    }
    return 'Dose';
  }

  // Helper method to get full display text
  String get fullDisplayText {
    return '$scheduleLabel dose ($displayName)';
  }

  TimeOfDay? _parseTimeOfDay(String time) {
    try {
      // Handle 24-hour format (14:30)
      if (time.contains(':') && !time.contains(' ')) {
        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
      
      // Handle 12-hour format (2:30 PM)
      if (time.contains(' ')) {
        final parts = time.split(' ');
        final timePart = parts[0];
        final ampm = parts[1].toUpperCase();
        
        final timeParts = timePart.split(':');
        var hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        if (ampm == 'PM' && hour != 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;
        
        return TimeOfDay(hour: hour, minute: minute);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'ScheduleModel(id: $id, time: $time, displayName: $fullDisplayText)';
  }
}

// Simple model for UI dropdown items
class ScheduleDisplayItem {
  final String scheduleId;
  final String displayText;
  final String time;
  final LogStatus? currentStatus; // null if not logged yet

  ScheduleDisplayItem({
    required this.scheduleId,
    required this.displayText,
    required this.time,
    this.currentStatus,
  });

  bool get isLogged => currentStatus != null;
  bool get isTaken => currentStatus == LogStatus.taken;
  bool get isMissed => currentStatus == LogStatus.missed;

  // Display text with status indicator
  String get displayTextWithStatus {
    if (isTaken) return '$displayText ✅';
    if (isMissed) return '$displayText ❌';
    return displayText;
  }

  @override
  String toString() {
    return 'ScheduleDisplayItem(scheduleId: $scheduleId, displayText: $displayTextWithStatus)';
  }
}


class ScheduleLogModelWithLog {
  /// The schedule information.
  final ScheduleLogModel schedule;

  /// The log entry for this specific schedule on a specific date.
  /// Can be null if no log entry exists yet.
  final LogModel? log;

  /// The index of this schedule time within the medication's List<TimeOfDay> scheduleTimes.
  /// This is crucial for mapping to the takenScheduleIndices list in the global LogModel.
  final int scheduleIndex;

  ScheduleLogModelWithLog({
    required this.schedule,
    this.log,
    required this.scheduleIndex, // Added required scheduleIndex parameter
  });

  /// Indicates whether this schedule has been logged for the specific date.
  bool get isLogged => log != null;

  /// Indicates whether the scheduled dose was marked as taken.
  /// Returns false if not logged or if the log status is not 'taken'.
  bool get isTaken => log?.status == LogStatus.taken;

  /// Indicates whether the scheduled dose was marked as missed.
  /// Returns false if not logged or if the log status is not 'missed'.
  bool get isMissed => log?.status == LogStatus.missed;

  /// Indicates whether the scheduled time has passed for today.
  bool get isPast {
    // Parse the time string from the schedule using the existing helper
    // ScheduleLogModel._parseTimeOfDay is private, so we need our own copy
    // or make it static/public in ScheduleLogModel.
    // Let's use a local copy for now, adapted for robustness.
    final timeOfDay = _parseTimeOfDay(schedule.time);
    if (timeOfDay == null) {
      // If we can't parse the time, we can't determine if it's past.
      // It's safer to assume it's not past or handle as needed.
      return false;
    }

    final now = TimeOfDay.now();
    // Compare hours first
    if (timeOfDay.hour < now.hour) {
      return true; // Scheduled hour is earlier than current hour
    } else if (timeOfDay.hour > now.hour) {
      return false; // Scheduled hour is later than current hour
    }
    // Hours are equal, compare minutes
    return timeOfDay.minute < now.minute;
  }

  // Local helper to parse time string, adapted from ScheduleLogModel._parseTimeOfDay
  // This makes the class self-contained for the isPast calculation.
  TimeOfDay? _parseTimeOfDay(String timeString) {
    try {
      // Prioritize 24-hour format (14:30) as it's simpler and likely used internally
      if (timeString.contains(':') && !timeString.contains(' ')) {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          // Validate ranges
          if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
            return TimeOfDay(hour: hour, minute: minute);
          }
        }
      }

      // Fallback to 12-hour format (2:30 PM) parsing if needed
      if (timeString.contains(' ')) {
        final parts = timeString.split(' ');
        if (parts.length == 2) {
          final timePart = parts[0];
          final ampm = parts[1].toUpperCase();

          final timeParts = timePart.split(':');
          if (timeParts.length == 2) {
            var hour = int.tryParse(timeParts[0]);
            final minute = int.tryParse(timeParts[1]);

            if (hour != null && minute != null && minute >= 0 && minute <= 59) {
              if (ampm == 'PM' && hour != 12) hour += 12;
              if (ampm == 'AM' && hour == 12) hour = 0;
              // Validate final hour
              if (hour >= 0 && hour <= 23) {
                 return TimeOfDay(hour: hour, minute: minute);
              }
            }
          }
        }
      }

      // Parsing failed or format not recognized
      return null;
    } catch (e) {
      // Catch any unexpected errors during parsing
      debugPrint('Error parsing time string "$timeString": $e');
      return null;
    }
  }

  @override
  String toString() {
    return 'ScheduleLogModelWithLog(schedule: $schedule, log: $log, scheduleIndex: $scheduleIndex)';
  }
}
// --- End of updated addition ---