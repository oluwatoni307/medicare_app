// routes.dart
// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:medicare_app/features/medication_list/medication_list_view.dart';
import 'features/AddMedication/AddMedication_view.dart';
import 'features/Home/Home_view.dart';
import 'features/auth/view/auth.dart';
import 'features/auth/view/onboard.dart';
import 'features/auth/view/splash.dart';
import 'features/log/log_view.dart';
import 'features/analysis/analysis_view.dart';
import 'features/profile/profile_view.dart';

class AppRoutes {
  // Auth & Onboarding routes
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';

  // Existing routes
  static const String home = '/';
  static const String new_medicine = '/new_medicine';
  static const String log = '/log';
  static const String edit_medication = '/edit';
  static const String medication_list = '/medication_list';
  static const String analysis = '/analysis';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
    // Auth & Onboarding routes
    splash: (context) => SplashScreen(),
    onboarding: (context) => OnboardingScreen(),
    auth: (context) => AuthScreen(),

    // Existing routes
    home: (context) => const Homepage(),
    edit_medication: (context) => MedicationView(),
    medication_list: (context) => const MedicationListView(),
    new_medicine: (context) => MedicationView(),
    log: (context) =>
        LogView(medicineId: '270cb55f-bcd0-42cd-9f62-1d22eaaa2c1d'),
    analysis: (context) => AnalysisDashboardView(),
    profile: (context) => ProfilePage(),
  };
}
