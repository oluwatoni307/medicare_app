import 'package:hive/hive.dart';

part 'log.g.dart'; 

@HiveType(typeId: 1)
class LogModel extends HiveObject {
  @HiveField(0)
  final String medId;
  
  @HiveField(1)
  final DateTime date;
  
  @HiveField(2)
  final double percent;
  
  // Tracks which specific schedule indices were taken
  // Index corresponds to Med.scheduleTimes list index
  // 1 = taken, 0 = not taken (initially all 0)
  @HiveField(3) 
  final List<int> takenScheduleIndices; 

  LogModel({
    required this.medId,
    required this.date,
    required this.percent,
    required this.takenScheduleIndices,
  });

  // Corrected factory: Initializes with zeros
  factory LogModel.forMedication({
    required String medId,
    required DateTime date,
    required int scheduleLength, // Length of Med.scheduleTimes
  }) {
    return LogModel(
      medId: medId,
      date: date,
      percent: 0.0,
      takenScheduleIndices: List<int>.filled(scheduleLength, 0, growable: false), // All 0s
    );
  }

  // Convenience method to check if a specific schedule time (by index) was taken
  bool wasScheduleTaken(int index) {
    // Safety check for index bounds
    if (index < 0 || index >= takenScheduleIndices.length) {
      return false; // Or throw an exception, depending on desired behavior
    }
    return takenScheduleIndices[index] == 1;
  }

  // Method to mark a specific schedule time as taken
  // Returns true if the state changed (wasn't already taken)
  bool markScheduleTaken(int index) {
    if (index < 0 || index >= takenScheduleIndices.length) {
      return false; // Invalid index
    }
    if (takenScheduleIndices[index] == 1) {
      return false; // Already taken
    }
    // This approach requires creating a new list for immutability
    // If Hive allows direct modification, you could modify takenScheduleIndices[index] = 1
    // and then recalculate percent and save the object.
    return true; // Indicate state change needed
  }

  // Convenience method to get the number of doses taken
  int get dosesTaken => takenScheduleIndices.where((status) => status == 1).length;

  @override
  String toString() => 'LogModel(medId: $medId, date: $date, percent: $percent, takenIndices: $takenScheduleIndices)';
}