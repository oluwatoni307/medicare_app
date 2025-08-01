// notification_viewmodel.dart
// ignore_for_file: unused_local_variable, pattern_never_matches_value_type

import 'dart:developer' as developer; // Import for logging if needed
import 'package:flutter/foundation.dart';
// If needed for test notification
import 'service.dart'; // Assuming this exports NotificationService and NotificationResult types
import 'notifications_model.dart';

/// === NOTIFICATION VIEWMODEL OVERVIEW ===
/// Purpose: UI state management for notification settings and permissions
/// Dependencies: NotificationService (updated version returning NotificationResult)
class NotificationViewModel extends ChangeNotifier {
  final NotificationService _notificationService;

  // === STATE PROPERTIES ===
  bool _isLoading = false;
  String? _error;
  bool _permissionGranted = false; // Derived from service initialization or permission request
  NotificationSettingsModel _settings = const NotificationSettingsModel();
  int _pendingNotificationsCount = 0;

  NotificationViewModel({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService.instance; // Use singleton instance by default

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
      final result = await _notificationService.initialize();
      switch (result) {
        case NotificationSuccess():
          _settings = _notificationService.settings;
          // Assume permissions might be granted if init succeeds, or check explicitly if needed
          // A more robust approach might involve a separate check or assuming granted on success
          // For now, let's assume initialization implies potential permission grant
          // (This logic might need refinement based on your service's exact init behavior)
          _permissionGranted = true; // Tentative, might be refined
          developer.log('NotificationService initialized: ${result.message ?? "Success"}');
        case NotificationError(message: final message, exception: final exception):
          _setError('Initialization failed: $message');
          developer.log('NotificationService initialization error: $message', error: exception);
          // Permission might be denied or other issues, set granted to false tentatively
          _permissionGranted = false;
          // Optionally, you could set a specific error state if initialization failure implies permission issues
      }
      // Always try to update the count after init attempt
      await _updatePendingCount();
    } catch (e, s) { // Catch unexpected errors outside NotificationResult
      _setError('Unexpected error during initialization: $e');
      developer.log('Unexpected error in NotificationViewModel.initialize', error: e, stackTrace: s);
    } finally {
      _setLoading(false);
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _notificationService.requestPermissions();
      switch (result) {
        case NotificationSuccess(message: final message):
          _permissionGranted = true;
          developer.log('Permissions granted: ${message ?? "Success"}');
        case NotificationError(message: final message, exception: final exception):
          _permissionGranted = false;
          _setError('Permission request failed: $message');
          developer.log('Permission request error: $message', error: exception);
      }
      notifyListeners(); // Notify after setting permissionGranted
      return _permissionGranted;
    } catch (e, s) { // Catch unexpected errors
      _permissionGranted = false;
      _setError('Unexpected error requesting permissions: $e');
      developer.log('Unexpected error in NotificationViewModel.requestPermissions', error: e, stackTrace: s);
      notifyListeners();
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
      final result = await _notificationService.updateSettings(newSettings);
       switch (result) {
        case NotificationSuccess():
          _settings = newSettings;
          await _updatePendingCount(); // Update count as disabling might cancel notifications
          developer.log('Notifications ${enabled ? "enabled" : "disabled"}');
        case NotificationError(message: final message, exception: final exception):
          _setError('Failed to ${enabled ? "enable" : "disable"} notifications: $message');
          developer.log('Toggle notifications error: $message', error: exception);
      }
    } catch (e, s) {
      _setError('Unexpected error toggling notifications: $e');
      developer.log('Unexpected error in NotificationViewModel.toggleNotifications', error: e, stackTrace: s);
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
      final result = await _notificationService.cancelAllNotifications();
       switch (result) {
        case NotificationSuccess(message: final message):
          developer.log(message ?? "All notifications cancelled");
        case NotificationError(message: final message, exception: final exception):
          _setError('Failed to cancel notifications: $message');
          developer.log('Cancel all notifications error: $message', error: exception);
      }
      await _updatePendingCount(); // Refresh count after cancellation
    } catch (e, s) {
      _setError('Unexpected error cancelling notifications: $e');
      developer.log('Unexpected error in NotificationViewModel.cancelAllNotifications', error: e, stackTrace: s);
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh pending notifications count
  Future<void> refreshPendingCount() async {
    await _updatePendingCount();
  }

  /// Test notification (for settings screen)
  /// Note: You'll need to add a `scheduleTestNotification` method to your NotificationService
  /// that accepts a NotificationModel and schedules it.
  Future<void> sendTestNotification() async {
    _setLoading(true);
    _clearError();

    try {
      final testNotification = NotificationModel(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Notification',
        body: 'This is a test notification from your medicine app',
        scheduledTime: DateTime.now().add(const Duration(seconds: 5)),
        medicineId: 'test',
        scheduleId: 'test',
      );

      // You need to implement this method in NotificationService
      // e.g., Future<NotificationResult> scheduleTestNotification(NotificationModel notification)
      final result = "";//await _notificationService.scheduleTestNotification(testNotification); // Hypothetical method
       switch (result) {
        case NotificationSuccess(message: final message):
          developer.log(message ?? "Test notification scheduled");
        case NotificationError(message: final message, exception: final exception):
         // Don't necessarily show this as a UI error, maybe just log it
          developer.log('Failed to schedule test notification: $message', error: exception);
          // Optionally, set a less intrusive message or handle differently
          // _setError('Could not send test notification: $message');
      }
    } catch (e, s) {
      _setError('Unexpected error sending test notification: $e');
      developer.log('Unexpected error in NotificationViewModel.sendTestNotification', error: e, stackTrace: s);
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
      final result = await _notificationService.updateSettings(newSettings);
       switch (result) {
        case NotificationSuccess():
          _settings = newSettings;
          developer.log('Setting updated');
        case NotificationError(message: final message, exception: final exception):
          _setError('Failed to update setting: $message');
          developer.log('Update setting error: $message', error: exception);
      }
    } catch (e, s) {
      _setError('Unexpected error updating setting: $e');
      developer.log('Unexpected error in NotificationViewModel._updateSetting', error: e, stackTrace: s);
    } finally {
      _setLoading(false);
    }
  }

  /// Update pending notifications count
  Future<void> _updatePendingCount() async {
    try {
      // getPendingNotificationsCount returns int directly, not NotificationResult
      _pendingNotificationsCount = await _notificationService.getPendingNotificationsCount();
      notifyListeners();
    } catch (e, s) {
      // Don't show error for count update failures in UI, but log it
      developer.log('Failed to update pending count: $e', error: e, stackTrace: s);
      // Optionally, you could set count to -1 or a specific error state if needed by UI
    }
  }

  /// Set loading state and notify
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error message and notify
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error message and notify
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}

/// === NOTIFICATION PERMISSION VIEWMODEL ===
/// Purpose: Handle permission request flow
/// Note: This could potentially be simplified or merged with the main ViewModel
/// since it largely duplicates permission request logic.
class NotificationPermissionViewModel extends ChangeNotifier {
  final NotificationService _notificationService;

  bool _isRequesting = false;
  bool _permissionGranted = false;
  bool _permissionDenied = false;
  bool _showRationale = false;

  NotificationPermissionViewModel({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService.instance;

  // === GETTERS ===
  bool get isRequesting => _isRequesting;
  bool get permissionGranted => _permissionGranted;
  bool get permissionDenied => _permissionDenied;
  bool get showRationale => _showRationale;

  /// Request notification permissions with UI flow
  Future<void> requestPermission() async {
    _isRequesting = true;
    _permissionDenied = false;
    _showRationale = false; // Reset rationale state on new request
    notifyListeners();

    try {
      final result = await _notificationService.requestPermissions();
      switch (result) {
        case NotificationSuccess():
          _permissionGranted = true;
          _permissionDenied = false;
          developer.log('Permissions granted via PermissionViewModel');
        case NotificationError():
          _permissionGranted = false;
          _permissionDenied = true;
          _showRationale = true; // Show rationale on explicit denial/error
          // ignore: unnecessary_type_check
          developer.log('Permissions denied or error via PermissionViewModel: ${result is NotificationError ? result.message : 'Unknown error'}');
      }
    } catch (e, s) { // Catch unexpected errors
      _permissionGranted = false;
      _permissionDenied = true;
      _showRationale = true;
      developer.log('Unexpected error in NotificationPermissionViewModel.requestPermission', error: e, stackTrace: s);
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

  /// Reset permission state (e.g., if user goes to system settings and returns)
  void reset() {
    _permissionGranted = false;
    _permissionDenied = false;
    _showRationale = false;
    _isRequesting = false; // Also reset requesting state
    notifyListeners();
  }
}