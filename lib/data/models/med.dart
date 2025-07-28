import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'med.g.dart';

@HiveType(typeId: 0)
class Med {
  @HiveField(0) final String id;
  @HiveField(1) final String name;
  @HiveField(2) final String dosage;
  @HiveField(3) final String type;
  @HiveField(4) final List<TimeOfDay> scheduleTimes; // Changed to TimeOfDay
  @HiveField(5) final DateTime startAt;
  @HiveField(6) final DateTime? endAt;

  Med({
    required this.id,
    required this.name,
    required this.dosage,
    required this.type,
    required this.scheduleTimes,
    required this.startAt,
    this.endAt,
  });
}