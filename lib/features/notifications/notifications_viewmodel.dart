// notifications_viewmodel.dart – enhanced with full settings management
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'service.dart';

/// Main notification settings view model - manages global notification preferences
class NotificationViewModel extends ChangeNotifier {
  final _service = NotificationService.instance;
  
  bool _isLoading = false;
  String? _error;
  int _pendingCount = 0;
  
  // Global notification settings (would be persisted in real app)
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  int _reminderMinutesBefore = 0; // 0, 5, 10, 15, 30, 60 minutes
  bool _missedDoseReminders = true;
  int _missedDoseDelayMinutes = 15; // 15, 30, 60 minutes
  int _maxMissedReminders = 2;

  static var instance; // 1, 2, 3

  // UI State getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingNotificationsCount => _pendingCount;
  
  // Settings getters
  NotificationSettings get settings => NotificationSettings(
    notificationsEnabled: _notificationsEnabled,
    soundEnabled: _soundEnabled,
    vibrationEnabled: _vibrationEnabled,
    reminderMinutesBefore: _reminderMinutesBefore,
    missedDoseReminders: _missedDoseReminders,
    missedDoseDelayMinutes: _missedDoseDelayMinutes,
    maxMissedReminders: _maxMissedReminders,
  );

  // Individual setting getters for UI binding
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  int get reminderMinutesBefore => _reminderMinutesBefore;
  bool get missedDoseReminders => _missedDoseReminders;
  int get missedDoseDelayMinutes => _missedDoseDelayMinutes;
  int get maxMissedReminders => _maxMissedReminders;

  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Check permissions
      _notificationsEnabled = await _service.hasPermissions;
      
      // Load settings from storage (in real app)
      await _loadSettingsFromStorage();
      
      await refreshPendingCount();
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshPendingCount() async {
    try {
      _pendingCount = await _service.scheduledCount;
      notifyListeners();
    } catch (e) {
      _setError('Failed to refresh count: $e');
    }
  }

  /* ---------- MAIN NOTIFICATION TOGGLE ---------- */

  Future<void> toggleNotifications(bool enabled) async {
    _setLoading(true);
    try {
      if (enabled) {
        // Request permissions first
        final hasPermissions = await _service.hasPermissions;
        if (!hasPermissions) {
          await _service.init(); // This will request permissions
          _notificationsEnabled = await _service.hasPermissions;
        } else {
          _notificationsEnabled = true;
        }
        
        // If we have permissions, reschedule all medicines with current settings
        if (_notificationsEnabled) {
          await _rescheduleAllMedicines();
        }
      } else {
        _notificationsEnabled = false;
        // Cancel all notifications
        await _service.cancelAllNotifications();
      }
      
      await _saveSettingsToStorage();
      await refreshPendingCount();
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /* ---------- INDIVIDUAL SETTING UPDATES ---------- */

  Future<void> updateSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _saveSettingsToStorage();
    notifyListeners();
    // Sound/vibration don't require rescheduling - they're channel-level settings
  }

  Future<void> updateVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _saveSettingsToStorage();
    notifyListeners();
  }

  Future<void> updateReminderMinutes(int minutes) async {
    if (_reminderMinutesBefore == minutes) return;
    
    _setLoading(true);
    try {
      _reminderMinutesBefore = minutes;
      await _saveSettingsToStorage();
      
      // This affects scheduling, so reschedule all if notifications are enabled
      if (_notificationsEnabled) {
        await _rescheduleAllMedicines();
        await refreshPendingCount();
      }
      
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateMissedDoseReminders(bool value) async {
    if (_missedDoseReminders == value) return;
    
    _setLoading(true);
    try {
      _missedDoseReminders = value;
      await _saveSettingsToStorage();
      
      // This affects scheduling, so reschedule all if notifications are enabled
      if (_notificationsEnabled) {
        await _rescheduleAllMedicines();
        await refreshPendingCount();
      }
      
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateMissedDoseDelay(int minutes) async {
    if (_missedDoseDelayMinutes == minutes) return;
    
    _setLoading(true);
    try {
      _missedDoseDelayMinutes = minutes;
      await _saveSettingsToStorage();
      
      // This affects scheduling, so reschedule all if notifications are enabled
      if (_notificationsEnabled) {
        await _rescheduleAllMedicines();
        await refreshPendingCount();
      }
      
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateMaxMissedReminders(int count) async {
    if (_maxMissedReminders == count) return;
    
    _setLoading(true);
    try {
      _maxMissedReminders = count;
      await _saveSettingsToStorage();
      
      // This affects scheduling, so reschedule all if notifications are enabled
      if (_notificationsEnabled) {
        await _rescheduleAllMedicines();
        await refreshPendingCount();
      }
      
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /* ---------- UTILITY METHODS ---------- */

  Future<void> sendTestNotification() async {
    try {
      final success = await _service.sendTest();
      if (!success) {
        _setError('Failed to send test notification');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> cancelAllNotifications() async {
    _setLoading(true);
    try {
      await _service.cancelAllNotifications();
      await refreshPendingCount();
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Get breakdown of notifications by medicine
  Future<Map<String, int>> getNotificationsByMedicine() async {
    try {
      return await _service.getScheduledCountByMedicine();
    } catch (e) {
      _setError(e.toString());
      return {};
    }
  }

  /* ---------- PRIVATE METHODS ---------- */

  /// Reschedule all medicines with current settings (called when settings change)
  Future<void> _rescheduleAllMedicines() async {
    // In a real app, you'd:
    // 1. Get all active medicines from your medicine service/repository
    // 2. Call _service.rescheduleAllForMedicine() for each one
    
    // For now, this is a placeholder
    // Example:
    /*
    final medicines = await MedicineRepository.instance.getActiveMedicines();
    for (final medicine in medicines) {
      await _service.rescheduleAllForMedicine(
        medicineId: medicine.id,
        medicineName: medicine.name,
        dosage: medicine.dosage,
        dailyTimes: medicine.times,
        durationDays: medicine.remainingDays,
        settings: settings,
      );
    }
    */
  }

Future<void> _loadSettingsFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
  _soundEnabled = prefs.getBool('soundEnabled') ?? true;
  _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
  _reminderMinutesBefore = prefs.getInt('reminderMinutesBefore') ?? 0;
  _missedDoseReminders = prefs.getBool('missedDoseReminders') ?? false;
  _missedDoseDelayMinutes = prefs.getInt('missedDoseDelayMinutes') ?? 15;
  _maxMissedReminders = prefs.getInt('maxMissedReminders') ?? 2;
}

Future<void> _saveSettingsToStorage() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('notificationsEnabled', _notificationsEnabled);
  await prefs.setBool('soundEnabled', _soundEnabled);
  await prefs.setBool('vibrationEnabled', _vibrationEnabled);
  await prefs.setInt('reminderMinutesBefore', _reminderMinutesBefore);
  await prefs.setBool('missedDoseReminders', _missedDoseReminders);
  await prefs.setInt('missedDoseDelayMinutes', _missedDoseDelayMinutes);
  await prefs.setInt('maxMissedReminders', _maxMissedReminders);
}
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Permission flow view model - minimal
class NotificationPermissionViewModel extends ChangeNotifier {
  final _service = NotificationService.instance;
  
  bool _isRequesting = false;
  bool _permissionGranted = false;
  bool _showRationale = false;
  String? _errorMessage;

  bool get isRequesting => _isRequesting;
  bool get permissionGranted => _permissionGranted;
  bool get showRationale => _showRationale;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  Future<void> requestPermission() async {
    _isRequesting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Request permissions through service init
      await _service.init();
      
      // Check if we got them
      _permissionGranted = await _service.hasPermissions;
      
      if (!_permissionGranted) {
        _showRationale = true;
        _errorMessage = 'Please enable notifications in your device settings';
      }
    } catch (e) {
      _errorMessage = 'Failed to request permissions: $e';
    } finally {
      _isRequesting = false;
      notifyListeners();
    }
  }
}

/// Enhanced settings model with all notification options
class NotificationSettings {
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int reminderMinutesBefore;
  final bool missedDoseReminders;
  final int missedDoseDelayMinutes;
  final int maxMissedReminders;

  const NotificationSettings({
    this.notificationsEnabled = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.reminderMinutesBefore = 0,
    this.missedDoseReminders = true,
    this.missedDoseDelayMinutes = 15,
    this.maxMissedReminders = 2,
  });

  /// Convenience getters for UI
  String get preReminderText {
    if (reminderMinutesBefore == 0) return 'Disabled';
    return '$reminderMinutesBefore minutes before';
  }

  String get missedDoseText {
    if (!missedDoseReminders) return 'Disabled';
    return 'Every $missedDoseDelayMinutes min (max $maxMissedReminders)';
  }
}

/// Extension for common reminder minute options
extension ReminderOptions on NotificationSettings {
  static const List<int> preReminderOptions = [0, 5, 10, 15, 30, 60];
  static const List<int> missedDelayOptions = [15, 30, 60];
  static const List<int> maxReminderOptions = [1, 2, 3];
  
  static String formatPreReminderOption(int minutes) {
    return minutes == 0 ? 'No pre-reminder' : '$minutes minutes before';
  }
  
  static String formatMissedDelayOption(int minutes) {
    return 'Every $minutes minutes';
  }
}