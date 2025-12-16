import 'package:flutter/material.dart';
import '../../../main.dart';
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

    final authService = AuthService();
    final currentUser = await authService.getCurrentUser();

    if (!mounted) return;

    if (currentUser != null) {
      if (!navigatedFromNotification) {
        Navigator.pushReplacementNamed(context, '/');
      }
      return;
    }

    final hasSeenOnboarding = await AppStateManager.hasSeenOnboarding();

    if (!mounted) return;

    if (hasSeenOnboarding) {
      Navigator.pushReplacementNamed(context, '/auth');
    } else {
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
            // Your app logo/icon
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
