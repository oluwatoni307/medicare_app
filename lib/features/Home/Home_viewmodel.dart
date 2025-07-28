import 'package:flutter/material.dart';
import 'service.dart';
import './Home_model.dart';
import '../auth/service.dart';

class HomeViewModel extends ChangeNotifier {
  final DBhelper _dbHelper = DBhelper();
  final AuthService _authService = AuthService();
  HomepageData _homepageData = HomepageData.initial();
  bool _isLoading = false;
  String? _errorMessage;

  HomepageData get homepageData => _homepageData;
  List<MedicationInfo> get medications => _homepageData.medications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
 
  Future<void> loadMedicines(String userId) async {
    print('Loading medicines for user: $userId');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Test database connection first
      
      // Load homepage data
      _homepageData = await _dbHelper.getHomepageData(userId);
      print('Loaded homepage data: $_homepageData');
      
      // If no data found, try alternative methods
      // if (_homepageData.medications.isEmpty) {
      //   print('No medicines found in schedules, trying all medicines...');
      //   try {
      //     final allMedicines = await _dbHelper.getAllUserMedicines(userId);
      //     final medications = allMedicines
      //         .map((med) => MedicationInfo.fromMap(med))
      //         .toList();
          
      //     _homepageData = HomepageData(
      //       upcomingMedicationCount: medications.length,
      //       medications: medications,
      //     );
      //     print('Alternative data loaded: $_homepageData');
      //   } catch (e) {
      //     print('Failed to get all medicines, trying medicines with active schedules...');
      //     try {
      //       final activeMedicines = await _dbHelper.getMedicinesWithActiveSchedules(userId);
      //       final medications = activeMedicines
      //           .map((med) => MedicationInfo.fromMap(med))
      //           .toList();
            
      //       _homepageData = HomepageData(
      //         upcomingMedicationCount: medications.length,
      //         medications: medications,
      //       );
      //       print('Active medicines data loaded: $_homepageData');
      //     } catch (e2) {
      //       print('All fallback methods failed: $e2');
      //     }
      //   }
      // }
      
    } catch (e) {
      print('Error loading medicines: $e');
      _errorMessage = 'Failed to load medicines: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Convenience method to load current user's medications
  Future<void> loadCurrentUserMedications() async {
    print('Loading current user medications...');
    final user = _authService.getCurrentUser();
    if (user != null) {
      print('Current user found: ${user.id}');
      await loadMedicines(user.id);
    } else {
      print('No current user found');
      _errorMessage = 'User not logged in';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh medications
  Future<void> refresh() async {
    print('Refreshing medications...');
    await loadCurrentUserMedications();
  }

  // // Method to manually set test data (for debugging)
  // void setTestData() {
  //   _homepageData = HomepageData(
  //     upcomingMedicationCount: 2,
  //     medications: [
  //       MedicationInfo(name: 'Aspirin', type: 'pill'),
  //       MedicationInfo(name: 'Insulin', type: 'injection'),
  //     ],
  //   );
  //   _isLoading = false;
  //   _errorMessage = null;
  //   notifyListeners();
  // }
}