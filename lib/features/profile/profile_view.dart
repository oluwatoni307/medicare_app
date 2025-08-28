import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sync.dart';
import 'service.dart';
import 'profile_widget.dart';
import '/navBar.dart';

/// === PROFILE PAGE ===
/// Purpose: Main profile screen with user info, stats, and quick actions
class ProfilePage extends StatefulWidget {

  const ProfilePage({
    Key? key,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late ProfileViewModel _profileViewModel;

  @override
  void initState() {
    super.initState();
    _profileViewModel = ProfileViewModel();
    
    // Load profile data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _profileViewModel.loadProfile();
    });
  }

  @override
  void dispose() {
    _profileViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _profileViewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            Consumer<ProfileViewModel>(
              builder: (context, viewModel, child) {
                return IconButton(
                  icon: viewModel.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: viewModel.isLoading
                      ? null
                      : () => viewModel.refreshProfile(),
                  tooltip: 'Refresh',
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 3,),
        body: Consumer<ProfileViewModel>(
          builder: (context, viewModel, child) {
            // Loading state
            if (viewModel.isLoading && viewModel.profile == null) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Error state
            if (viewModel.error != null && viewModel.profile == null) {
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
                      'Failed to load profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      viewModel.error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => viewModel.loadProfile(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // Profile loaded
            if (viewModel.profile == null) {
              return const Center(
                child: Text('No profile data available'),
              );
            }

            return RefreshIndicator(
              onRefresh: () => viewModel.refreshProfile(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Header
                    ProfileHeader(
                      user: viewModel.profile!.user,
                      onEditTap: () => _showEditProfileDialog(context),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Mini Stats
                    MiniStats(
                      stats: viewModel.profile!.stats,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Quick Actions
                    QuickActions(
                      onNotificationsTap: () => _navigateToNotifications(context),
                      onBackupMedicineTap: () => _navigateToBackupMedicine(context),
                      onSignOutTap: () => _showSignOutDialog(context),
                      isSigningOut: viewModel.isSigningOut,
                    ),
                    
                    // Error message at bottom if exists
                    if (viewModel.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                viewModel.error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Navigate to notifications page
  void _navigateToNotifications(BuildContext context) {
    // TODO: Replace with your actual navigation
    Navigator.pushNamed(context, '/notifications');
    
    // For now, show placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigate to notification settings'),
      ),
    );
  }

  /// Backup medicine data
  void _navigateToBackupMedicine(BuildContext context) async {
    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Backing up medicine data...'),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      final success = await backupAllToSingleJson();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Backup completed successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Backup failed. Please try again.'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Backup error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Show edit profile dialog
  void _showEditProfileDialog(BuildContext context) {
    final viewModel = context.read<ProfileViewModel>();
    if (viewModel.profile == null) return;

    final nameController = TextEditingController(
      text: viewModel.profile!.user.name,
    );
    final emailController = TextEditingController(
      text: viewModel.profile!.user.email ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              
              if (name.isNotEmpty) {
                await viewModel.updateUserName(name);
              }
              
              if (email.isNotEmpty && email != viewModel.profile!.user.email) {
                await viewModel.updateUserEmail(email);
              }
              
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

/// Show sign out confirmation dialog
void _showSignOutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out of your account?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            
            // Just call signOut() - no context needed since navigation is handled internally
            final success = await context.read<ProfileViewModel>().signOut();
            
           if (success && context.mounted) {
              // Navigate to auth page after successful sign out
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/auth',
                (route) => false,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );
}
}