import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../routes.dart';
import '../app_state_manager.dart';
import '/features/auth/service.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    await Future.delayed(const Duration(seconds: 2));

    // Check if app was opened from notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    final authService = AuthService();
    final currentUser = await authService.getCurrentUser();

    if (!mounted) return;

    // If user is logged in
    if (currentUser != null) {
      if (initialMessage != null) {
        // User is logged in AND opened from notification (TERMINATED state)
        final medicineId = initialMessage.data['medicine_id'];

        if (medicineId != null) {
          debugPrint(
            '🔔 [TERMINATED] Navigating to home first, then to log page',
          );

          // CRITICAL FIX: Navigate to Homepage first, THEN push LogView
          // This ensures Homepage is in the navigation stack
          Navigator.pushReplacementNamed(context, AppRoutes.home);

          // Wait for Homepage to build, then push LogView on top
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushNamed(
                context,
                AppRoutes.log,
                arguments: medicineId,
              );
              debugPrint('✅ [TERMINATED] Pushed LogView on top of Homepage');
            }
          });
        } else {
          // No medicine_id, just go to home
          debugPrint('🔔 [TERMINATED] No medicine_id, navigating to home');
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        // Normal login flow - no notification, just go to home
        debugPrint('✅ Normal login flow - navigating to home');
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
      return;
    }

    // If user is NOT logged in, check onboarding status
    // (Notifications won't work if not logged in anyway)
    final hasSeenOnboarding = await AppStateManager.hasSeenOnboarding();

    if (!mounted) return;

    if (hasSeenOnboarding) {
      debugPrint('✅ User has seen onboarding - navigating to auth');
      Navigator.pushReplacementNamed(context, '/auth');
    } else {
      debugPrint('✅ First time user - navigating to onboarding');
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'MedStracker',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
