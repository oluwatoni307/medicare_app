import 'package:flutter/foundation.dart';
import 'service.dart';
import 'notifications_model.dart';

/// === NOTIFICATION VIEWMODEL OVERVIEW ===
/// Purpose: UI state management for notification settings and permissions
/// Dependencies: NotificationService
class NotificationViewModel extends ChangeNotifier {
  final NotificationService _notificationService;
  
  // === STATE PROPERTIES ===
  bool _isLoading = false;
  String? _error;
  bool _permissionGranted = false;
  NotificationSettingsModel _settings = const NotificationSettingsModel();
  int _pendingNotificationsCount = 0;

  NotificationViewModel({NotificationService? notificationService}) 
      : _notificationService = notificationService ?? NotificationService();

  // === GETTERS ===
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get permissionGranted => _permissionGranted;
  NotificationSettingsModel get settings => _settings;
  int get pendingNotificationsCount => _pendingNotificationsCount;

  // === PUBLIC METHODS ===
  
  /// Initialize notification system
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      final initialized = await _notificationService.initialize();
      if (initialized) {
        _settings = _notificationService.settings;
        await _updatePendingCount();
      }
    } catch (e) {
      _setError('Failed to initialize notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    _setLoading(true);
    _clearError();

    try {
      _permissionGranted = await _notificationService.requestPermissions();
      
      if (!_permissionGranted) {
        _setError('Notification permission denied');
      }
      
      return _permissionGranted;
    } catch (e) {
      _setError('Failed to request permissions: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle notifications on/off
  Future<void> toggleNotifications(bool enabled) async {
    if (_settings.notificationsEnabled == enabled) return;
    
    _setLoading(true);
    _clearError();

    try {
      final newSettings = _settings.copyWith(notificationsEnabled: enabled);
      await _notificationService.updateSettings(newSettings);
      _settings = newSettings;
      
      await _updatePendingCount();
    } catch (e) {
      _setError('Failed to update notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update sound setting
  Future<void> updateSoundEnabled(bool enabled) async {
    await _updateSetting((settings) => settings.copyWith(soundEnabled: enabled));
  }

  /// Update vibration setting
  Future<void> updateVibrationEnabled(bool enabled) async {
    await _updateSetting((settings) => settings.copyWith(vibrationEnabled: enabled));
  }

  /// Update reminder minutes before
  Future<void> updateReminderMinutes(int minutes) async {
    await _updateSetting((settings) => settings.copyWith(reminderMinutesBefore: minutes));
  }

  /// Update missed dose reminders
  Future<void> updateMissedDoseReminders(bool enabled) async {
    await _updateSetting((settings) => settings.copyWith(missedDoseReminders: enabled));
  }

  /// Update missed dose delay
  Future<void> updateMissedDoseDelay(int minutes) async {
    await _updateSetting((settings) => settings.copyWith(missedDoseDelayMinutes: minutes));
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    _setLoading(true);
    _clearError();

    try {
      await _notificationService.cancelAllNotifications();
      await _updatePendingCount();
    } catch (e) {
      _setError('Failed to cancel notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh pending notifications count
  Future<void> refreshPendingCount() async {
    await _updatePendingCount();
  }

  /// Test notification (for settings screen)
  Future<void> sendTestNotification() async {
    _setLoading(true);
    _clearError();

    try {
      final _ = NotificationModel(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Notification',
        body: 'This is a test notification from your medicine app',
        scheduledTime: DateTime.now().add(const Duration(seconds: 5)),
        medicineId: 'test',
        scheduleId: 'test',
      );

      // Schedule test notification 5 seconds from now
      // This would need to be implemented in NotificationService
      // await _notificationService.scheduleTestNotification(testNotification);
    } catch (e) {
      _setError('Failed to send test notification: $e');
    } finally {
      _setLoading(false);
    }
  }

  // === PRIVATE METHODS ===

  /// Generic setting update helper
  Future<void> _updateSetting(NotificationSettingsModel Function(NotificationSettingsModel) updater) async {
    _setLoading(true);
    _clearError();

    try {
      final newSettings = updater(_settings);
      await _notificationService.updateSettings(newSettings);
      _settings = newSettings;
    } catch (e) {
      _setError('Failed to update setting: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update pending notifications count
  Future<void> _updatePendingCount() async {
    try {
      _pendingNotificationsCount = await _notificationService.getPendingNotificationsCount();
      notifyListeners();
    } catch (e) {
      // Don't show error for count update failures
      debugPrint('Failed to update pending count: $e');
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error message
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}

/// === NOTIFICATION PERMISSION VIEWMODEL ===
/// Purpose: Handle permission request flow
class NotificationPermissionViewModel extends ChangeNotifier {
  final NotificationService _notificationService;
  
  bool _isRequesting = false;
  bool _permissionGranted = false;
  bool _permissionDenied = false;
  bool _showRationale = false;

  NotificationPermissionViewModel({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  // === GETTERS ===
  bool get isRequesting => _isRequesting;
  bool get permissionGranted => _permissionGranted;
  bool get permissionDenied => _permissionDenied;
  bool get showRationale => _showRationale;

  /// Request notification permissions with UI flow
  Future<void> requestPermission() async {
    _isRequesting = true;
    _permissionDenied = false;
    notifyListeners();

    try {
      _permissionGranted = await _notificationService.requestPermissions();
      
      if (!_permissionGranted) {
        _permissionDenied = true;
        _showRationale = true;
      }
    } catch (e) {
      _permissionDenied = true;
      _showRationale = true;
    } finally {
      _isRequesting = false;
      notifyListeners();
    }
  }

  /// Dismiss rationale dialog
  void dismissRationale() {
    _showRationale = false;
    notifyListeners();
  }

  /// Reset permission state
  void reset() {
    _permissionGranted = false;
    _permissionDenied = false;
    _showRationale = false;
    notifyListeners();
  }
}