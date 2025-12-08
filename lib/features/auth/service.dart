import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserModel> signUp(
    String email,
    String password, {
    String name = 'User',
  }) async {
    try {
      // Perform Supabase auth sign-up
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null || response.user!.email == null) {
        throw Exception('Sign-up failed: No user or email found');
      }

      // Insert into users table and retrieve the inserted record
      final _ = await _client
          .from('users')
          .insert({
            'id': response.user!.id,
            'name': name,
            'email': response.user!.email,
          })
          .select()
          .single();

      return UserModel(
        id: response.user!.id,
        email: response.user!.email!,
        name: name,
      );
    } catch (e) {
      throw Exception('Sign-up error: $e');
    }
  }

  Future<UserModel> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw Exception('Sign-in failed');
      }
      return UserModel(id: response.user!.id, email: response.user!.email!);
    } catch (e) {
      throw Exception('Sign-in error: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Sign-out error: $e');
    }
  }

  // NEW: Forgot Password - Direct reset for demo app
  Future<bool> resetPassword(String email, String newPassword) async {
    try {
      // First, check if user exists with this email
      final userResponse = await _client
          .from('users')
          .select('id')
          .eq('email', email.toLowerCase())
          .maybeSingle();

      if (userResponse == null) {
        throw Exception('No account found with this email address');
      }

      // For demo purposes, we'll use the regular auth update
      // Note: This requires the user to be signed in, so we'll need to sign them in temporarily

      // Method 1: Try to sign in first, then update password
      try {
        // Get the current user's session if any
        final currentUser = _client.auth.currentUser;

        // If no current user or different user, we can't directly update password
        // For demo, we'll throw a helpful error
        if (currentUser == null ||
            currentUser.email?.toLowerCase() != email.toLowerCase()) {
          throw Exception(
            'For demo purposes: Please sign in first, then use "Change Password" feature. Direct password reset requires additional setup.',
          );
        }

        // If same user is signed in, allow password update
        final response = await _client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        if (response.user == null) {
          throw Exception('Failed to update password');
        }

        return true;
      } catch (e) {
        throw Exception('Password reset failed: $e');
      }
    } catch (e) {
      throw Exception('Reset password error: $e');
    }
  }

  // Alternative method: Send reset email (standard way)
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: "myapp://reset-password", // ✅ deep link for mobile app
      );
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        // Fetch user's name from database
        final userData = await _client
            .from('users')
            .select('name')
            .eq('id', user.id)
            .single();

        return UserModel(
          id: user.id,
          email: user.email!,
          name: userData['name'] ?? 'User',
        );
      } catch (e) {
        // If fetching name fails, return user without name
        return UserModel(id: user.id, email: user.email!, name: 'User');
      }
    }
    return null;
  }
}
// // Test class for service layer
// class AuthServiceTest {
//   final AuthService _authService = AuthService();
  
//   // Test method to run basic functionality
//   Future<void> runTests() async {
//     print('🧪 Starting AuthService Tests...\n');
    
//     try {
//       // Test 1: Check current user
//       print('Test 1: Check current user');
//       final currentUser = _authService.getCurrentUser();
//       print('Current user: ${currentUser?.email ?? 'No user signed in'}\n');
      
//       // Test 2: Test reset password (will likely fail without proper setup)
//       print('Test 2: Test reset password');
//       try {
//         final testEmail = 'tester@gmail.com';
//         final newPassword = 'newPassword123';
        
//         final result = await _authService.resetPassword(testEmail, newPassword);
//         print('Reset password result: $result\n');
//       } catch (e) {
//         print('Reset password test failed (expected): $e\n');
//       }
      
//       // Test 3: Test send reset email
//       print('Test 3: Test send reset email');
//       try {
//         await _authService.sendPasswordResetEmail('test@example.com');
//         print('Reset email sent successfully\n');
//       } catch (e) {
//         print('Send reset email failed: $e\n');
//       }
      
//       print('✅ AuthService tests completed');
      
//     } catch (e) {
//       print('❌ Test error: $e');
//     }
//   }
// }

// // Usage example:
// // To test the service layer, you can call:
// // final tester = AuthServiceTest();
// // await tester.runTests();