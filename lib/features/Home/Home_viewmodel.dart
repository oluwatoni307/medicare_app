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

  // Getters
  HomepageData get homepageData => _homepageData;
  List<MedicationInfo> get medications => _homepageData.medications;
  TodaysSummary? get todaysSummary => _homepageData.todaysSummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get showSummary => _homepageData.hasSummary;

  Future<void> loadMedicines(String userId) async {
    print('Loading medicines for user: $userId');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load homepage data (now includes todaysSummary)
      _homepageData = await _dbHelper.getHomepageData(userId);
      print('Loaded homepage data: $_homepageData');
      
      if (_homepageData.todaysSummary != null) {
        print('Today\'s summary: ${_homepageData.todaysSummary}');
      }
    } catch (e) {
      print('Error loading medicines: $e');
      _errorMessage = 'Failed to load medicines: $e';
    }
    
    _isLoading = false;
    notifyListeners();
  }

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

  Future<void> refresh() async {
    print('Refreshing medications...');
    await loadCurrentUserMedications();
  }
}