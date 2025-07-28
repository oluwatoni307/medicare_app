import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notifications_viewmodel.dart';

/// === NOTIFICATION SETTINGS VIEW ===
/// Purpose: Main settings screen for notification preferences
class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationViewModel(),
      child: const _NotificationSettingsContent(),
    );
  }
}

class _NotificationSettingsContent extends StatefulWidget {
  const _NotificationSettingsContent({Key? key}) : super(key: key);

  @override
  State<_NotificationSettingsContent> createState() => _NotificationSettingsContentState();
}

class _NotificationSettingsContentState extends State<_NotificationSettingsContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationViewModel>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          Consumer<NotificationViewModel>(
            builder: (context, viewModel, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: viewModel.isLoading ? null : viewModel.refreshPendingCount,
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.error != null) {
            return _buildErrorView(context, viewModel);
          }

          return _buildSettingsContent(context, viewModel);
        },
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, NotificationViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => viewModel.initialize(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context, NotificationViewModel viewModel) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Card
        _buildStatusCard(context, viewModel),
        const SizedBox(height: 16),
        
        // Main Toggle
        _buildMainToggleSection(context, viewModel),
        const SizedBox(height: 16),
        
        // Notification Settings
        if (viewModel.settings.notificationsEnabled) ...[
          _buildNotificationSettingsSection(context, viewModel),
          const SizedBox(height: 16),
        ],
        
        // Actions Section
        _buildActionsSection(context, viewModel),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, NotificationViewModel viewModel) {
    final theme = Theme.of(context);
    final isEnabled = viewModel.settings.notificationsEnabled;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isEnabled ? Icons.notifications_active : Icons.notifications_off,
              color: isEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEnabled ? 'Notifications Active' : 'Notifications Disabled',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${viewModel.pendingNotificationsCount} scheduled reminders',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainToggleSection(BuildContext context, NotificationViewModel viewModel) {
    return Card(
      child: SwitchListTile(
        title: const Text('Enable Notifications'),
        subtitle: const Text('Turn on/off all medicine reminders'),
        value: viewModel.settings.notificationsEnabled,
        onChanged: (value) => viewModel.toggleNotifications(value),
        secondary: const Icon(Icons.notifications),
      ),
    );
  }

  Widget _buildNotificationSettingsSection(BuildContext context, NotificationViewModel viewModel) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Notification Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            title: const Text('Sound'),
            subtitle: const Text('Play sound with notifications'),
            value: viewModel.settings.soundEnabled,
            onChanged: (value) => viewModel.updateSoundEnabled(value),
            secondary: const Icon(Icons.volume_up),
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            subtitle: const Text('Vibrate device for notifications'),
            value: viewModel.settings.vibrationEnabled,
            onChanged: (value) => viewModel.updateVibrationEnabled(value),
            secondary: const Icon(Icons.vibration),
          ),
          ListTile(
            title: const Text('Remind me before'),
            subtitle: Text('${viewModel.settings.reminderMinutesBefore} minutes before dose time'),
            leading: const Icon(Icons.schedule),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReminderTimePicker(context, viewModel),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Missed Dose Alerts'),
            subtitle: const Text('Remind me if I miss a dose'),
            value: viewModel.settings.missedDoseReminders,
            onChanged: (value) => viewModel.updateMissedDoseReminders(value),
            secondary: const Icon(Icons.warning_amber),
          ),
          if (viewModel.settings.missedDoseReminders)
            ListTile(
              title: const Text('Missed dose delay'),
              subtitle: Text('Alert ${viewModel.settings.missedDoseDelayMinutes} minutes after missed dose'),
              leading: const SizedBox(width: 24),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showMissedDoseDelayPicker(context, viewModel),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, NotificationViewModel viewModel) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Test Notification'),
            subtitle: const Text('Send a test notification'),
            leading: const Icon(Icons.send),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => viewModel.sendTestNotification(),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Cancel All Notifications'),
            subtitle: const Text('Remove all scheduled reminders'),
            leading: Icon(
              Icons.cancel_schedule_send,
              color: Theme.of(context).colorScheme.error,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCancelAllDialog(context, viewModel),
          ),
        ],
      ),
    );
  }

  void _showReminderTimePicker(BuildContext context, NotificationViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reminder Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many minutes before dose time should I remind you?'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [0, 5, 10, 15, 30].map((minutes) {
                final isSelected = viewModel.settings.reminderMinutesBefore == minutes;
                return FilterChip(
                  label: Text(minutes == 0 ? 'On time' : '$minutes min'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      viewModel.updateReminderMinutes(minutes);
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMissedDoseDelayPicker(BuildContext context, NotificationViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Missed Dose Delay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How long after a missed dose should I remind you?'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [15, 30, 60, 120].map((minutes) {
                final isSelected = viewModel.settings.missedDoseDelayMinutes == minutes;
                return FilterChip(
                  label: Text('${minutes} min'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      viewModel.updateMissedDoseDelay(minutes);
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCancelAllDialog(BuildContext context, NotificationViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel All Notifications'),
        content: const Text(
          'This will remove all scheduled medication reminders. You can reschedule them by toggling notifications off and on again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.cancelAllNotifications();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel All'),
          ),
        ],
      ),
    );
  }
}

/// === NOTIFICATION PERMISSION VIEW ===
/// Purpose: Handle notification permission request flow
class NotificationPermissionView extends StatefulWidget {
  final VoidCallback? onPermissionGranted;
  
  const NotificationPermissionView({
    Key? key,
    this.onPermissionGranted,
  }) : super(key: key);

  @override
  State<NotificationPermissionView> createState() => _NotificationPermissionViewState();
}

class _NotificationPermissionViewState extends State<NotificationPermissionView> {
  late NotificationPermissionViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = NotificationPermissionViewModel();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enable Notifications'),
        ),
        body: Consumer<NotificationPermissionViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.permissionGranted) {
              return _buildSuccessView(context);
            }
            
            return _buildPermissionRequestView(context, viewModel);
          },
        ),
      ),
    );
  }

  Widget _buildPermissionRequestView(BuildContext context, NotificationPermissionViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_active,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Stay on Track',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Enable notifications to receive timely reminders for your medications. Never miss a dose again!',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          if (viewModel.isRequesting)
            const CircularProgressIndicator()
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await viewModel.requestPermission();
                  if (viewModel.permissionGranted && widget.onPermissionGranted != null) {
                    widget.onPermissionGranted!();
                  }
                },
                child: const Text('Enable Notifications'),
              ),
            ),
          
          const SizedBox(height: 16),
          
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          
          if (viewModel.showRationale) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notifications help ensure you take your medications on time. You can enable them later in Settings.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'All Set!',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Notifications are now enabled. You\'ll receive reminders for all your scheduled medications.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (widget.onPermissionGranted != null) {
                  widget.onPermissionGranted!();
                }
              },
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}