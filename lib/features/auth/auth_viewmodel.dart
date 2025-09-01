import 'package:flutter/material.dart';
import '../../sync.dart';
import 'service.dart';
import 'auth_model.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;
  AuthViewModel(this._authService);
 
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  UserModel? _user;

  // Getters
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  UserModel? get user => _user;

  // Clear messages
  void clearMessages() {
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();
  }

  Future<void> signUp(String email, String password, {String name = 'User'}) async {
    _setLoading(true);
    _clearMessages();
    
    try {
      _user = await _authService.signUp(email, password, name: name);
      // No need to restore on signup - new user has no data
      _setLoading(false);
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
    }
  }

  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    _clearMessages();
    
    try {
      _user = await _authService.signIn(email, password);
     
      // Try to restore user's data after successful sign in
      await restoreFromSingleJson();
     
      _setLoading(false);
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
    }
  }

  Future<void> signOut(BuildContext context) async {
    _setLoading(true);
    _clearMessages();
    
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
     
      _setLoading(false);
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
    }
  }

  // NEW: Send Password Reset Email
  Future<bool> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) {
      _setError('Please enter your email address');
      return false;
    }

    if (!_isValidEmail(email)) {
      _setError('Please enter a valid email address');
      return false;
    }

    _setLoading(true);
    _clearMessages();
    
    try {
      await _authService.sendPasswordResetEmail(email.trim().toLowerCase());
      _setSuccess('Password reset email sent to $email. Please check your inbox and follow the instructions to reset your password.');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  void checkCurrentUser() {
    _user = _authService.getCurrentUser();
    notifyListeners();
  }

  // Private helper methods for cleaner code
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _successMessage = ''; // Clear success when setting error
    notifyListeners();
  }

  void _setSuccess(String success) {
    _successMessage = success;
    _errorMessage = ''; // Clear error when setting success
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = '';
    _successMessage = '';
  }

  // Basic email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }
}

// Test class for ViewModel
class AuthViewModelTest {
  late AuthViewModel _viewModel;
  
  AuthViewModelTest(AuthService authService) {
    _viewModel = AuthViewModel(authService);
  }
  
  Future<void> runTests() async {
    print('🧪 Starting AuthViewModel Tests...\n');
    
    try {
      // Test 1: Initial state
      print('Test 1: Initial state');
      print('Loading: ${_viewModel.isLoading}');
      print('Error: ${_viewModel.errorMessage}');
      print('Success: ${_viewModel.successMessage}');
      print('User: ${_viewModel.user?.email ?? 'null'}\n');
      
      // Test 2: Email validation
      print('Test 2: Email validation tests');
      
      // Test empty email
      var result = await _viewModel.sendPasswordResetEmail('');
      print('Empty email result: $result');
      print('Error message: ${_viewModel.errorMessage}\n');
      
      // Test invalid email
      _viewModel.clearMessages();
      result = await _viewModel.sendPasswordResetEmail('invalid-email');
      print('Invalid email result: $result');
      print('Error message: ${_viewModel.errorMessage}\n');
      
      // Test valid email
      _viewModel.clearMessages();
      result = await _viewModel.sendPasswordResetEmail('test@example.com');
      print('Valid email result: $result');
      print('Success message: ${_viewModel.successMessage}');
      print('Error message: ${_viewModel.errorMessage}\n');
      
      print('✅ AuthViewModel tests completed');
      
    } catch (e) {
      print('❌ ViewModel test error: $e');
    }
  }
}

// Usage example:
// To test the viewmodel:
// final authService = AuthService();
// final tester = AuthViewModelTest(authService);
// await tester.runTests();