import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_model.dart';

/// === PROFILE VIEWMODEL OVERVIEW ===
/// Purpose: State management for profile page data and actions with Supabase integration
/// Dependencies: Supabase client for user/medicine data operations
class ProfileViewModel extends ChangeNotifier {
  static SupabaseClient get _client => Supabase.instance.client;
  
  // === STATE PROPERTIES ===
  bool _isLoading = false;
  String? _error;
  ProfileModel? _profile;
  bool _isSigningOut = false;

  // === GETTERS ===
  bool get isLoading => _isLoading;
  String? get error => _error;
  ProfileModel? get profile => _profile;
  bool get isSigningOut => _isSigningOut;
  
  // Convenience getters
  ProfileUserModel? get user => _profile?.user;
  ProfileStatsModel? get stats => _profile?.stats;

  // === PUBLIC METHODS ===
  
  /// Load user profile and statistics from Supabase
  Future<void> loadProfile() async {
    _setLoading(true);
    _clearError();

    try {
      // Get current user from Supabase auth session
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw 'No authenticated user found';
      }
      
      final userId = currentUser.id;
      print("Loading profile for authenticated user: $userId");
      
      // 1. Fetch user data
      final userData = await _getUserById(userId);
      if (userData == null) {
        throw 'User not found';
      }
      
      // 2. Fetch medicine count
      final medicineCount = await _getMedicineCountForUser(userId);
      
      // 3. Fetch last activity (most recent log entry)
      final lastActivity = await _getLastActivityForUser(userId);
      
      // Create profile models
      final profileUser = ProfileUserModel(
        id: userData['id'],
        name: userData['name'] ?? 'Unknown User',
        email: userData['email'] ?? '',
        createdAt: DateTime.parse(userData['created_at']),
      );
      
      final profileStats = ProfileStatsModel(
        totalMedicines: medicineCount,
        lastActivity: lastActivity,
      );
      
      _profile = ProfileModel(
        user: profileUser,
        stats: profileStats,
      );
      
      print("Profile loaded successfully");
      
    } catch (e) {
      print('Error loading profile: $e');
      _setError('Failed to load profile: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    await loadProfile();
  }

  /// Update user name in Supabase and local state
  Future<void> updateUserName(String newName) async {
    // Get current user from auth session
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      _setError('No authenticated user found');
      return;
    }
    
    _setLoading(true);
    _clearError();

    try {
      print("Updating user name to: $newName");
      
      // Update in Supabase
      final response = await _client
          .from('users')
          .update({'name': newName})
          .eq('id', currentUser.id)
          .select();
      
      if (response.isEmpty) {
        throw 'Failed to update user name in database';
      }
      
      // Update local state
      if (_profile != null) {
        _profile = _profile!.copyWith(
          user: _profile!.user.copyWith(name: newName),
        );
      }
      
      print("User name updated successfully");
      
    } catch (e) {
      print('Error updating user name: $e');
      _setError('Failed to update name: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update user email in Supabase and local state
  Future<void> updateUserEmail(String newEmail) async {
    // Get current user from auth session
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      _setError('No authenticated user found');
      return;
    }
    
    _setLoading(true);
    _clearError();

    try {
      print("Updating user email to: $newEmail");
      
      // Update in Supabase
      final response = await _client
          .from('users')
          .update({'email': newEmail})
          .eq('id', currentUser.id)
          .select();
      
      if (response.isEmpty) {
        throw 'Failed to update user email in database';
      }
      
      // Update local state
      if (_profile != null) {
        _profile = _profile!.copyWith(
          user: _profile!.user.copyWith(email: newEmail),
        );
      }
      
      print("User email updated successfully");
      
    } catch (e) {
      print('Error updating user email: $e');
      _setError('Failed to update email: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out user - clear Supabase session and local data
  Future<bool> signOut() async {
    _isSigningOut = true;
    _clearError();
    notifyListeners();

    try {
      print("Signing out user");
      
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

  // === PRIVATE DATABASE METHODS ===

  /// Get user by ID from Supabase
  Future<Map<String, dynamic>?> _getUserById(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('id, name, email, created_at')
          .eq('id', userId)
          .single();
      
      return response;
    } catch (e) {
      print('Error fetching user: $e');
      throw 'Error fetching user data: $e';
    }
  }

  /// Get medicine count for user from Supabase
  Future<int> _getMedicineCountForUser(String userId) async {
    try {
      final response = await _client
          .from('medicines')
          .select('id')
          .eq('user_id', userId);
      
      return response.length;
    } catch (e) {
      print('Error fetching medicine count: $e');
      throw 'Error fetching medicine count: $e';
    }
  }

  /// Get last activity for user from Supabase
  Future<DateTime?> _getLastActivityForUser(String userId) async {
    try {
      final response = await _client
          .from('logs')
          .select('''
            created_at,
            schedules!inner(
              medicines!inner(user_id)
            )
          ''')
          .eq('schedules.medicines.user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);
      
      if (response.isNotEmpty) {
        return DateTime.parse(response.first['created_at']);
      }
      
      return null;
    } catch (e) {
      print('Error fetching last activity: $e');
      throw 'Error fetching last activity: $e';
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

  // === UTILITY METHODS ===

  /// Test database connection
  Future<void> testDatabaseConnection() async {
    try {
      await _client.from('users').select().limit(1);
      print('Profile database connection successful');
    } catch (e) {
      print('Error connecting to database: $e');
    }
  }
}