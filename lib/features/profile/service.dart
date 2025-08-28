// profile_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../sync.dart';
import 'profile_model.dart';
import '../auth/service.dart';
import '/data/models/med.dart'; // Hive Med with List<TimeOfDay> scheduleTimes

/// === PROFILE VIEWMODEL OVERVIEW ===
/// Purpose: State management for profile page data with hybrid approach
/// - User profile: LOCAL ONLY (no Supabase queries for name/email)
/// - Medicine  Local Hive storage
class ProfileViewModel extends ChangeNotifier {
  static SupabaseClient get _client => Supabase.instance.client;
  final AuthService _authService = AuthService();
  
  // === STATE PROPERTIES ===
  bool _isLoading = false;
  String? _error;
  ProfileModel? _profile;
  bool _isSigningOut = false;
  Box<Med>? _medicationsBox; // Make it nullable to avoid LateInitializationError

  // === GETTERS ===
  bool get isLoading => _isLoading;
  String? get error => _error;
  ProfileModel? get profile => _profile;
  bool get isSigningOut => _isSigningOut;
  
  // Convenience getters
  ProfileUserModel? get user => _profile?.user;
  ProfileStatsModel? get stats => _profile?.stats;

  // === INITIALIZATION ===
  ProfileViewModel() {
    _init();
  }

  Future<void> _init() async {
    await _openMedicationsBox();
  }

  Future<void> _openMedicationsBox() async {
    try {
      _medicationsBox = await Hive.openBox<Med>('meds');
    } catch (e) {
      print('Error opening medications box: $e');
      _medicationsBox = null;
    }
  }

  // === PUBLIC METHODS ===
  
  /// Load user profile and statistics (LOCAL ONLY)
  Future<void> loadProfile() async {
    _setLoading(true);
    _clearError();

    try {
      // Get current user from auth service (this is LOCAL - from auth session)
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        throw 'No authenticated user found';
      }
      
      
      // 1. USE LOCAL DATA ONLY - no Supabase queries for name/email
      // The AuthService.getCurrentUser() gives us ID and email from local auth session
      // For name, we assume it's available locally or use a default
      
      // 2. Get medicine count from LOCAL Hive storage
        await _openMedicationsBox(); // <-- ADD THIS LINE

      final medicineCount = _getLocalMedicineCount();
      
      // Create profile models using LOCAL data only
      final profileUser = ProfileUserModel(
        id: currentUser.id,
        name: currentUser.name ?? 'User', // Use name from local auth model
        email: currentUser.email,
        createdAt: DateTime.now(), // or store this locally
      );
      
      final profileStats = ProfileStatsModel(
        totalMedicines: medicineCount,
        lastActivity: null, // Local data only
      );
      
      _profile = ProfileModel(
        user: profileUser,
        stats: profileStats,
      );
      
      print("Profile loaded successfully (LOCAL ONLY)");
      
    } catch (e) {
      print('Error loading profile: $e');
      _setError('Failed to load profile: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh profile data (still LOCAL ONLY)
  Future<void> refreshProfile() async {
    await loadProfile();
  }

  /// Update user name - only update local state, no Supabase
  Future<void> updateUserName(String newName) async {
    _setLoading(true);
    _clearError();

    try {
      print("Updating user name locally to: $newName");
      
      // UPDATE LOCAL STATE ONLY - no Supabase calls for profile data
      if (_profile != null) {
        _profile = _profile!.copyWith(
          user: _profile!.user.copyWith(name: newName),
        );
      }
      
      print("User name updated successfully (LOCAL ONLY)");
      
    } catch (e) {
      print('Error updating user name: $e');
      _setError('Failed to update name: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update user email - only update local state, no Supabase
  Future<void> updateUserEmail(String newEmail) async {
    _setLoading(true);
    _clearError();

    try {
      print("Updating user email locally to: $newEmail");
      
      // UPDATE LOCAL STATE ONLY - no Supabase calls for profile data
      if (_profile != null) {
        _profile = _profile!.copyWith(
          user: _profile!.user.copyWith(email: newEmail),
        );
      }
      
      print("User email updated successfully (LOCAL ONLY)");
      
    } catch (e) {
      print('Error updating user email: $e');
      _setError('Failed to update email: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out user - clear Supabase session only
  Future<bool> signOut() async {
  _isSigningOut = true;
  _clearError();
  notifyListeners();
  try {
    print("Signing out user");
   
    // Backup data before signing out
    await backupAllToSingleJson();
   
    // Sign out from Supabase (clears session)
    await _client.auth.signOut();
   
    // Clear profile data
    _profile = null;
   
    print("User signed out successfully");
    return true;
    
  } catch (e) {
    print('Error signing out: $e');
    _setError('Failed to sign out: $e');
    return false;
  } finally {
    _isSigningOut = false;
    notifyListeners();
  }
}
  /// Clear any cached data
  void clearData() {
    _profile = null;
    _error = null;
    _isLoading = false;
    _isSigningOut = false;
    notifyListeners();
  }

  // === PRIVATE METHODS ===

  /// Get medicine count from LOCAL Hive storage
/// Get *active* medicine count from LOCAL Hive storage
int _getLocalMedicineCount() {
  try {
    if (_medicationsBox == null) return 0;
    final now = DateTime.now();
    return _medicationsBox!.values.where((med) {
      if (med.endAt == null) return true;
      return !med.endAt!.isBefore(now);
    }).length;
  } catch (e) {
    debugPrint('Error counting active medicines: $e');
    return 0;
  }
}
  // === PRIVATE STATE METHODS ===

  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error message
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}