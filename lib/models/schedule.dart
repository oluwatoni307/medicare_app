
class Schedule {
  int? id;
  int medicineid;
  String time;
  String days;
    String createdAt;

    Schedule({required this.id, required this.medicineid, required this.createdAt, required this.days, required this.time});


    Map <String, dynamic> changetoMap (){

      return{
        'id':id,
        "medicineid":medicineid,
        "createdAt":createdAt,
        "days": days,
        "time": time,
      };
    }

    factory Schedule.fromtheMap(Map<String, dynamic> map) {
      return Schedule(
        id: map['id'],
        medicineid: map['medicineid'],
        createdAt: map['createdAt'],
        days: map['days'],
        time: map['time'],
      );
    }
}