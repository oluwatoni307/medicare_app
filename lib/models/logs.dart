class log{

  int?id;
  int scheduleid;
  String date;
  String status;
  String createdAt;

  log({
    this.id,
    required this.scheduleid,
    required this.date,
    required this.status,
    required this.createdAt,
  });


  Map<String, dynamic> changetoMap() {
    return {
      'id': id,
      'schedule_id': scheduleid,
      'date': date,
      'status': status,
      'created_at': createdAt,
    };
  }



  factory log.fromtheMap(Map<String, dynamic> map) {
    return log(
      id: map['id'],
      scheduleid: map['schedule_id'],
      date: map['date'],
      status: map['status'],
      createdAt: map['created_at'],
    );
  }
}