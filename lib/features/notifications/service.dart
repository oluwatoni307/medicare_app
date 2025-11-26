import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  final _supabase = Supabase.instance.client;

  /// Initialize Firebase Messaging
  Future<void> init() async {
    if (_initialized) return;

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;
  }

  /// Fetch the FCM token (required for reminders)
  Future<String?> get fcmToken async {
    return await FirebaseMessaging.instance.getToken();
  }

  /* ---------------------------------------------------------
   * CREATE REMINDERS
   * --------------------------------------------------------- */

  Future<void> createReminders({
    required String userId,
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> dailyTimes,
    required int durationDays,
  }) async {
    final token = await fcmToken;
    if (token == null) {
      debugPrint("❌ Cannot create reminders: FCM token is null");
      return;
    }

    final now = DateTime.now();

    for (int day = 0; day < durationDays; day++) {
      final targetDate = now.add(Duration(days: day));
      final expiresOn = targetDate.toIso8601String().split('T')[0];

      for (final time in dailyTimes) {
        final timeString =
            '${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}:00';

        final scheduleId =
            '${medicineId}_${time.hour}${time.minute}_${targetDate.millisecondsSinceEpoch}';

        await _supabase.from('reminder').insert({
          'user_id': userId,
          'fcm_token': token,
          'medicine_id': medicineId,
          'schedule_id': scheduleId,
          'name': medicineName,
          'dose': dosage,
          'reminder_time': timeString,
          'expires_on': expiresOn,
        });
      }
    }

    debugPrint("✅ Created reminders for $medicineName");
  }

  /// Create one reminder entry per distinct time with an expiry date.
  /// The backend will handle recurrence; we only insert one row per time.
  Future<void> createSingleReminderEntries({
    required String userId,
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> dailyTimes,
    DateTime? expiresOn,
  }) async {
    final token = await fcmToken;
    if (token == null) {
      debugPrint("❌ Cannot create reminders: FCM token is null");
      return;
    }

    final expiresOnString = expiresOn == null
        ? null
        : expiresOn.toIso8601String().split('T')[0];

    for (final time in dailyTimes) {
      final timeString =
          '${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}:00';

      final scheduleId =
          '${medicineId}_${time.hour}${time.minute}_${expiresOn?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

      await _supabase.from('reminder').insert({
        'user_id': userId,
        'fcm_token': token,
        'medicine_id': medicineId,
        'schedule_id': scheduleId,
        'name': medicineName,
        'dose': dosage,
        'reminder_time': timeString,
        'expires_on': expiresOnString,
      });
    }

    debugPrint("✅ Created single reminder entries for $medicineName");
  }

  /* ---------------------------------------------------------
   * DELETE REMINDERS
   * --------------------------------------------------------- */

  Future<void> deleteReminders(String medicineId) async {
    await _supabase.from('reminder').delete().eq('medicine_id', medicineId);
    debugPrint("🗑 Deleted reminders for medicine $medicineId");
  }

  /* ---------------------------------------------------------
   * UPDATE REMINDERS (Delete then recreate)
   * --------------------------------------------------------- */

  Future<void> updateReminders({
    required String userId,
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> dailyTimes,
    required int durationDays,
  }) async {
    await deleteReminders(medicineId);
    await createReminders(
      userId: userId,
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      dailyTimes: dailyTimes,
      durationDays: durationDays,
    );
  }

  /// Update reminders by deleting existing entries and creating single entries per time with an expiry date.
  Future<void> updateRemindersWithExpiry({
    required String userId,
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> dailyTimes,
    DateTime? expiresOn,
  }) async {
    await deleteReminders(medicineId);
    await createSingleReminderEntries(
      userId: userId,
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      dailyTimes: dailyTimes,
      expiresOn: expiresOn,
    );
  }

  /* ---------------------------------------------------------
   * UTILITIES
   * --------------------------------------------------------- */

  Future<int> countForMedicine(String medicineId) async {
    final res = await _supabase
        .from('reminder')
        .select('id')
        .eq('medicine_id', medicineId);

    return res.length;
  }

  Future<int> totalScheduled() async {
    final res = await _supabase.from('reminder').select('id');
    return res.length;
  }

  Future<bool> sendTestNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    final token = await fcmToken;
    if (token == null) return false;

    await _supabase.from('reminder').insert({
      'user_id': userId,
      'fcm_token': token,
      'medicine_id': 'test',
      'schedule_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
      'name': title,
      'dose': message,
      'reminder_time': '00:00:00',
      'expires_on': DateTime.now().toIso8601String().split('T')[0],
    });

    return true;
  }
}
