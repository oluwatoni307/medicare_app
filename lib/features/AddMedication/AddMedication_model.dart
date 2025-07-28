// AddMedication_model.dart
import 'package:flutter/material.dart';

class MedicationModel {
  String? id; // UUID for medication
  String? medicationName;
  String? dosage;
  String? type;
  DateTime? startDate;
  List<TimeOfDay>? scheduleTimes; // List of exact times user wants to take medication
  String? duration; // Duration of schedule (e.g., "7 days", "indefinitely")

  MedicationModel({
    this.id,
    this.medicationName,
    this.dosage,
    this.type,
    this.startDate,
    this.scheduleTimes, // This is now the list of times user selected
    this.duration,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    List<TimeOfDay>? scheduleTimes;
    if (json['schedule_times'] != null) {
      scheduleTimes = (json['schedule_times'] as List<dynamic>)
          .map((timeStr) {
            final parts = (timeStr as String).split(':');
            return TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          })
          .toList()
          .cast<TimeOfDay>();
    }

    return MedicationModel(
      id: json['id'] as String?,
      medicationName: json['name'] as String?,
      dosage: json['dosage'] as String?,
      type: json['type'] as String?,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      scheduleTimes: scheduleTimes,
      duration: json['duration'] as String?,
    );
  }

  String get imageUrl {
    if (type == null) return 'images/types/default.png';
    return 'images/types/$type.png';
  }

  Map<String, dynamic> toJson() {
    List<String>? scheduleTimesJson;
    if (scheduleTimes != null) {
      scheduleTimesJson = scheduleTimes!
          .map((time) => time.formatTime())
          .toList();
    }

    return {
      'id': id,
      'name': medicationName,
      'dosage': dosage,
      'type': type,
      'start_date': startDate?.toIso8601String(),
      'schedule_times': scheduleTimesJson,
      'duration': duration,
    };
  }
}

// Extension to format TimeOfDay - moved here to avoid circular imports
extension TimeOfDayExtension on TimeOfDay {
  String formatTime() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}