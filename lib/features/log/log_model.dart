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
    return {'schedule_id': scheduleId, 'date': date, 'status': status.value};
  }

  @override
  String toString() {
    return 'LogModel(id: $id, scheduleId: $scheduleId, date: $date, status: $status)';
  }
}

/// Status of a medication log entry
enum LogStatus {
  /// Dose was taken and logged by user
  taken('taken'),

  /// Dose was explicitly marked as missed by user, or deadline passed without logging
  missed('missed'),

  /// Dose has not been logged yet (future or within grace period)
  notLogged('not_logged');

  const LogStatus(this.value);
  final String value;

  static LogStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'taken':
        return LogStatus.taken;
      case 'missed':
        return LogStatus.missed;
      case 'not_logged':
        return LogStatus.notLogged;
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

  String get displayName {
    final timeOfDay = _parseTimeOfDay(time);
    if (timeOfDay != null) {
      final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
      final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
      final minute = timeOfDay.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    }
    return time;
  }

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

  String get fullDisplayText {
    return '$scheduleLabel dose ($displayName)';
  }

  TimeOfDay? _parseTimeOfDay(String time) {
    try {
      if (time.contains(':') && !time.contains(' ')) {
        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }

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

class ScheduleDisplayItem {
  final String scheduleId;
  final String displayText;
  final String time;
  final LogStatus? currentStatus;

  ScheduleDisplayItem({
    required this.scheduleId,
    required this.displayText,
    required this.time,
    this.currentStatus,
  });

  bool get isLogged => currentStatus != null;
  bool get isTaken => currentStatus == LogStatus.taken;
  bool get isMissed => currentStatus == LogStatus.missed;

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
  final ScheduleLogModel schedule;
  final LogModel? log;
  final int scheduleIndex;

  ScheduleLogModelWithLog({
    required this.schedule,
    this.log,
    required this.scheduleIndex,
  });

  bool get isLogged => log != null;
  bool get isTaken => log?.status == LogStatus.taken;
  bool get isMissed => log?.status == LogStatus.missed;
  bool get isNotLogged => log?.status == LogStatus.notLogged || log == null;

  /// Returns true if this is an explicit miss (user logged it as missed)
  /// vs implicit miss (deadline passed without logging)
  bool get isExplicitMiss {
    if (!isMissed) return false;
    // If log exists with missed status, it's explicit
    // If log doesn't exist but status shows missed, it's implicit (time-based)
    return isLogged;
  }

  /// Returns true if the scheduled time has passed for today
  bool get isPast {
    final timeOfDay = _parseTimeOfDay(schedule.time);
    if (timeOfDay == null) return false;

    final now = TimeOfDay.now();
    if (timeOfDay.hour < now.hour) {
      return true;
    } else if (timeOfDay.hour > now.hour) {
      return false;
    }
    return timeOfDay.minute < now.minute;
  }

  /// Returns true if user can mark this dose as taken
  /// (not in the future, and not already taken)
  bool get canBeMarkedTaken {
    if (isTaken) return false;
    // Can't mark future doses as taken (unless we allow pre-logging)
    // For now, allow marking even future doses for flexibility
    return true;
  }

  /// Returns time remaining until deadline (scheduled time + grace period)
  /// Returns null if already past deadline
  Duration? get timeUntilDeadline {
    final timeOfDay = _parseTimeOfDay(schedule.time);
    if (timeOfDay == null) return null;

    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    // Add 2-hour grace period
    final deadline = scheduled.add(const Duration(hours: 2));

    if (now.isAfter(deadline)) return null;

    return deadline.difference(now);
  }

  /// Returns time since deadline passed
  /// Returns null if deadline hasn't passed yet
  Duration? get timeSinceDeadline {
    final timeOfDay = _parseTimeOfDay(schedule.time);
    if (timeOfDay == null) return null;

    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    final deadline = scheduled.add(const Duration(hours: 2));

    if (now.isBefore(deadline)) return null;

    return now.difference(deadline);
  }

  /// Human-readable status text with context
  String get statusDisplayText {
    if (isTaken) {
      return 'Taken ✅';
    } else if (isMissed) {
      if (isExplicitMiss) {
        return 'Marked as missed ❌';
      } else {
        final since = timeSinceDeadline;
        if (since != null) {
          return 'Missed (${_formatDuration(since)} ago) ⏰';
        }
        return 'Missed ⏰';
      }
    } else {
      // Not logged
      if (isPast) {
        final until = timeUntilDeadline;
        if (until != null) {
          return 'Pending (${_formatDuration(until)} left) ⏳';
        } else {
          return 'Missed (not logged) ⏰';
        }
      } else {
        return 'Not yet time ⏳';
      }
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min';
    } else {
      return 'just now';
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeString) {
    try {
      if (timeString.contains(':') && !timeString.contains(' ')) {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null &&
              minute != null &&
              hour >= 0 &&
              hour <= 23 &&
              minute >= 0 &&
              minute <= 59) {
            return TimeOfDay(hour: hour, minute: minute);
          }
        }
      }

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
              if (hour >= 0 && hour <= 23) {
                return TimeOfDay(hour: hour, minute: minute);
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing time string "$timeString": $e');
      return null;
    }
  }

  @override
  String toString() {
    return 'ScheduleLogModelWithLog(schedule: $schedule, log: $log, scheduleIndex: $scheduleIndex)';
  }
}
