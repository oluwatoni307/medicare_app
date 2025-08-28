
// backup_and_restore_json.dart
import 'dart:convert';
import 'package:flutter/material.dart'; // Added for TimeOfDay
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/data/models/med.dart';
import '/data/models/log.dart';

/* ---------- BACKUP (Hive → one JSON blob) ---------- */
Future<bool> backupAllToSingleJson() async {
  try {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) {
      print('No authenticated user found');
      return false;
    }

    // Check if boxes are open
    if (!Hive.isBoxOpen('meds') || !Hive.isBoxOpen('logs')) {
      print('Required Hive boxes are not open');
      return false;
    }

    // meds
    final meds = Hive.box<Med>('meds')
        .values
        .map((m) => {
              'id': m.id,
              'name': m.name,
              'dosage': m.dosage,
              'type': m.type,
              'scheduleTimes': m.scheduleTimes
                  .map((t) => {'hour': t.hour, 'minute': t.minute})
                  .toList(),
              'startAt': m.startAt.toIso8601String(),
              'endAt': m.endAt?.toIso8601String(),
            })
        .toList();

    // logs
    final logs = Hive.box<LogModel>('logs')
        .values
        .map((l) => {
              'medId': l.medId,
              'date': l.date.toIso8601String(),
              'percent': l.percent,
              'takenScheduleIndices': l.takenScheduleIndices,
            })
        .toList();

    final blob = jsonEncode({
      'meds': meds,
      'logs': logs,
      'version': '1.0', // Version for future compatibility
      'timestamp': DateTime.now().toIso8601String(),
    });

    await supa.from('user_backups').upsert({
      'user_id': uid,
      'backup_json': blob,
      'updated_at': DateTime.now().toIso8601String(),
    });

    print('Backup completed successfully');
    return true;
  } catch (e) {
    print('Backup failed: $e');
    return false;
  }
}

/* ---------- RESTORE (one JSON blob → Hive) ---------- */
Future<bool> restoreFromSingleJson() async {
  try {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) {
      print('No authenticated user found');
      return false;
    }

    final row = await supa
        .from('user_backups')
        .select('backup_json')
        .eq('user_id', uid)
        .maybeSingle();

    if (row == null || row['backup_json'] == null) {
      print('No backup found for user');
      return false;
    }

    final data = jsonDecode(row['backup_json']) as Map<String, dynamic>;

    // Validate data structure
    if (!data.containsKey('meds') || !data.containsKey('logs')) {
      print('Invalid backup format');
      return false;
    }

    // Check if boxes are open, open them if needed
    if (!Hive.isBoxOpen('meds')) {
      await Hive.openBox<Med>('meds');
    }
    if (!Hive.isBoxOpen('logs')) {
      await Hive.openBox<LogModel>('logs');
    }

    // meds
    final medBox = Hive.box<Med>('meds');
    await medBox.clear();
    
    for (final m in (data['meds'] as List)) {
      try {
        final times = (m['scheduleTimes'] as List)
            .map((e) => TimeOfDay(
                  hour: e['hour'] as int,
                  minute: e['minute'] as int,
                ))
            .toList();

        await medBox.put(
          m['id'],
          Med(
            id: m['id'] as String,
            name: m['name'] as String,
            dosage: m['dosage'] as String,
            type: m['type'] as String,
            scheduleTimes: times,
            startAt: DateTime.parse(m['startAt'] as String),
            endAt: m['endAt'] == null ? null : DateTime.parse(m['endAt'] as String),
          ),
        );
      } catch (e) {
        print('Error restoring med ${m['id']}: $e');
        // Continue with other meds even if one fails
        continue;
      }
    }

    // logs
    final logBox = Hive.box<LogModel>('logs');
    await logBox.clear();
    
    for (final l in (data['logs'] as List)) {
      try {
        final key = '${l['medId']}_${l['date']}';
        await logBox.put(
          key,
          LogModel(
            medId: l['medId'] as String,
            date: DateTime.parse(l['date'] as String),
            percent: (l['percent'] as num).toDouble(),
            takenScheduleIndices: (l['takenScheduleIndices'] as List).cast<int>(),
          ),
        );
      } catch (e) {
        print('Error restoring log ${l['medId']}_${l['date']}: $e');
        // Continue with other logs even if one fails
        continue;
      }
    }

    print('Restore completed successfully');
    return true;
  } catch (e) {
    print('Restore failed: $e');
    return false;
  }
}

/* ---------- UTILITY FUNCTIONS ---------- */

/// Check if a backup exists for the current user
Future<bool> hasBackup() async {
  try {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) return false;

    final row = await supa
        .from('user_backups')
        .select('user_id')
        .eq('user_id', uid)
        .maybeSingle();

    return row != null;
  } catch (e) {
    print('Error checking backup: $e');
    return false;
  }
}

/// Get backup metadata (timestamp, etc.)
Future<Map<String, dynamic>?> getBackupInfo() async {
  try {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supa
        .from('user_backups')
        .select('backup_json, updated_at')
        .eq('user_id', uid)
        .maybeSingle();

    if (row == null) return null;

    final data = jsonDecode(row['backup_json']) as Map<String, dynamic>;
    return {
      'updated_at': row['updated_at'],
      'version': data['version'] ?? 'unknown',
      'timestamp': data['timestamp'],
      'med_count': (data['meds'] as List).length,
      'log_count': (data['logs'] as List).length,
    };
  } catch (e) {
    print('Error getting backup info: $e');
    return null;
  }
}

/// Delete backup for current user
Future<bool> deleteBackup() async {
  try {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) return false;

    await supa.from('user_backups').delete().eq('user_id', uid);
    print('Backup deleted successfully');
    return true;
  } catch (e) {
    print('Error deleting backup: $e');
    return false;
  }
}