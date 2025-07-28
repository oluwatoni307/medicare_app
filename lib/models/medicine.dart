class Medicine {
  int? id;
  String name;
  String dosage;
  int userId;
  String createdAt;

  Medicine({
    this.id,
    required this.name,
    required this.dosage,
    required this.userId,
    required this.createdAt,
  });


  Map<String, dynamic> changetoMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'user_id': userId,
      'created_at': createdAt,
    };
  }

  factory Medicine.fromtheMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      dosage: map['dosage'],
      userId: map['user_id'],
      createdAt: map['created_at'],
    );
  }
}