// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LogModelAdapter extends TypeAdapter<LogModel> {
  @override
  final int typeId = 1;

  @override
  LogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LogModel(
      medId: fields[0] as String,
      date: fields[1] as DateTime,
      percent: fields[2] as double,
      takenScheduleIndices: (fields[3] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, LogModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.medId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.percent)
      ..writeByte(3)
      ..write(obj.takenScheduleIndices);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
