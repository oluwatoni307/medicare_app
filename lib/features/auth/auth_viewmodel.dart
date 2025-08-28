import 'package:flutter/material.dart';
import '../../sync.dart';
import 'service.dart';
import 'auth_model.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;

  AuthViewModel(this._authService);
  
  bool _isLoading = false;
  String _errorMessage = '';
  UserModel? _user;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  UserModel? get user => _user;

  Future<void> signUp(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      _user = await _authService.signUp(email, password);
      // No need to restore on signup - new user has no data
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      _user = await _authService.signIn(email, password);
      
      // Try to restore user's data after successful sign in
      await restoreFromSingleJson();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut(BuildContext context) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      // Backup data before signing out
      await backupAllToSingleJson();
      
      await _authService.signOut();
      _user = null;
      
      // Navigate to login page
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login', // Replace with your login route name
          (route) => false,
        );
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  void checkCurrentUser() {
    _user = _authService.getCurrentUser();
    notifyListeners();
  }
}