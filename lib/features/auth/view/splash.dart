import 'package:flutter/material.dart';
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

  Future<void> 
  _checkAppState() async {
    await Future.delayed(Duration(seconds: 2)); // Show splash
    
    // Check if user is already logged in
    final authService = AuthService();
    final currentUser = authService.getCurrentUser();
    
    if (currentUser != null) {
      // User is logged in - go to home
      Navigator.pushReplacementNamed(context, '/');
      return;
    }
    
    // Check if first time user
    final hasSeenOnboarding = await AppStateManager.hasSeenOnboarding();
    
    if (hasSeenOnboarding) {
      // Returning user, no auth - go to login
      Navigator.pushReplacementNamed(context, '/auth');
    } else {
      // First time user - show onboarding
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
            Text('MedStracker', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}