class user {
  final int? id;
  final String name;
  final String email;
  final String createdAt;

  user({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  Map<String, dynamic> changetoMap() {
    return {'id': id, 'name': name, 'email': email, 'created_at': createdAt};
  }

  factory user.fromtheMap(Map<String, dynamic> map) {
    return user(
      id: map["id"],
      name: map["name"],
      email: map["email"],
      createdAt: map["created_at"],
    );
  }
}
