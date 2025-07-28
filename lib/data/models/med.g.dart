// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'med.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedAdapter extends TypeAdapter<Med> {
  @override
  final int typeId = 0;

  @override
  Med read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Med(
      id: fields[0] as String,
      name: fields[1] as String,
      dosage: fields[2] as String,
      type: fields[3] as String,
      scheduleTimes: (fields[4] as List).cast<TimeOfDay>(),
      startAt: fields[5] as DateTime,
      endAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Med obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dosage)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.scheduleTimes)
      ..writeByte(5)
      ..write(obj.startAt)
      ..writeByte(6)
      ..write(obj.endAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
