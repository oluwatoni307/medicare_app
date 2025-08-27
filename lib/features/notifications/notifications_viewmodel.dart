// notifications_viewmodel.dart – lean implementation
import 'package:flutter/foundation.dart';
import 'service.dart';

/// Main notification settings view model - thin wrapper around service
class NotificationViewModel extends ChangeNotifier {
  final _service = NotificationService.instance;
  
  bool _isLoading = false;
  String? _error;
  int _pendingCount = 0;
  bool _notificationsEnabled = false;

  // UI State
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingNotificationsCount => _pendingCount;
  
  // Mock settings - in real app you'd load from storage
  NotificationSettings get settings => NotificationSettings(
    notificationsEnabled: _notificationsEnabled,
  );

  Future<void> initialize() async {
    _setLoading(true);
    try {
      _notificationsEnabled = await _service.hasPermissions;
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

  Future<void> toggleNotifications(bool enabled) async {
    _setLoading(true);
    try {
      if (enabled) {
        // In real app: request permissions first, then reschedule all
        _notificationsEnabled = await _service.hasPermissions;
      } else {
        // In real app: cancel all scheduled notifications
        _notificationsEnabled = false;
      }
      await refreshPendingCount();
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

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
      // In real app: call service to cancel all
      _pendingCount = 0;
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Mock methods - implement based on your needs
  void updateSoundEnabled(bool value) => notifyListeners();
  void updateVibrationEnabled(bool value) => notifyListeners();
  void updateReminderMinutes(int minutes) => notifyListeners();
  void updateMissedDoseReminders(bool value) => notifyListeners();
  void updateMissedDoseDelay(int minutes) => notifyListeners();

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

/// Mock settings model - replace with real implementation
class NotificationSettings {
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int reminderMinutesBefore;
  final bool missedDoseReminders;
  final int missedDoseDelayMinutes;

  const NotificationSettings({
    this.notificationsEnabled = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.reminderMinutesBefore = 0,
    this.missedDoseReminders = true,
    this.missedDoseDelayMinutes = 15,
  });
}