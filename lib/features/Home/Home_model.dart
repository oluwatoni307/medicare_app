// features/homepage/models/homepage_model.dart

class MedicationInfo {
  final String id;
  final String name;
  final String type;

  MedicationInfo({
    required this.id,
    required this.name,
    required this.type,
  });

  factory MedicationInfo.fromMap(Map<String, dynamic> map) {
    print('Parsing medication from map: $map');
    
    return MedicationInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown Medicine',
      type: map['type'] ?? 'pill',
    );
  }

  // Generate image URL based on medication type
  String get imageUrl {
    return 'images/types/$type.png';
  }

  @override
  String toString() {
    return 'MedicationInfo(id: $id, name: $name, type: $type)';
  }
}

class HomepageData {
  final int upcomingMedicationCount;
  final List<MedicationInfo> medications;

  HomepageData({
    required this.upcomingMedicationCount,
    required this.medications,
  });

  // Initial empty state
  factory HomepageData.initial() {
    return HomepageData(
      upcomingMedicationCount: 0,
      medications: [],
    );
  }

  @override
  String toString() {
    return 'HomepageData(count: $upcomingMedicationCount, medications: $medications)';
  }
}