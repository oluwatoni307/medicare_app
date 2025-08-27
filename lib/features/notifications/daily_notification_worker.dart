// daily_notification_worker.dart – minimal, no-bloat
import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

// --- adjust paths if needed ---
import '/data/models/med.dart';
import '/data/models/time_of_day_adapter.dart';
import 'service.dart';

const _kTask = "com.yourapp.daily_notification_task";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != _kTask) return false;

    // 1. Hive bootstrap – identical to original file
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(MedAdapter().typeId)) {
      Hive.registerAdapter(MedAdapter());
    }
    if (!Hive.isAdapterRegistered(TimeOfDayAdapter().typeId)) {
      Hive.registerAdapter(TimeOfDayAdapter());
    }
    final medsBox = await Hive.openBox<Med>('meds');

    // 2. Schedule today’s notifications
    final ok = await _scheduleToday(medsBox);
    await medsBox.close(); // only the box we opened
    return ok;
  });
}

/* ------------ private helpers ------------ */

Future<bool> _scheduleToday(Box<Med> box) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final meds = box.values.where((m) {
    final start = DateTime(m.startAt.year, m.startAt.month, m.startAt.day);
    final end = m.endAt == null
        ? null
        : DateTime(m.endAt!.year, m.endAt!.month, m.endAt!.day);
    return !start.isAfter(today) && (end == null || !today.isAfter(end));
  });

  final svc = NotificationService.instance;
  int ok = 0;
  for (final med in meds) {
    for (int i = 0; i < med.scheduleTimes.length; i++) {
      final tod = med.scheduleTimes[i];
      final dt = DateTime(today.year, today.month, today.day,
          tod.hour, tod.minute);
      if (dt.isBefore(now.add(const Duration(minutes: 5)))) continue;

      final id = '${med.id}_${today.millisecondsSinceEpoch}_$i';
      final success = await svc.schedule(
        medicineId: med.id,
        scheduleId: id,
        name: med.name,
        dosage: med.dosage,
        at: dt,
      );
      if (success) ok++;
    }
  }
  return ok > 0 || meds.isEmpty;
}

/* ------------ one-time registration ------------ */
Future<void> registerDailyWorker() async {
  await Workmanager().initialize(callbackDispatcher,
      isInDebugMode: kDebugMode);
  await Workmanager().cancelAll(); // dev only
  await Workmanager().registerPeriodicTask(
    'daily1',
    _kTask,
    frequency: const Duration(days: 1),
    initialDelay: _next6AM(),
    constraints: Constraints(networkType: NetworkType.not_required),
  );
}

Duration _next6AM() {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, 6);
  if (next.isBefore(now)) next = next.add(const Duration(days: 1));
  return next.difference(now);
}