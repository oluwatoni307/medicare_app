import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

Future<UserModel> signUp(String email, String password, {String name = 'User'}) async {
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
    final _ = await _client.from('users').insert({
      'id': response.user!.id,
      'name': name,
      'email': response.user!.email,
    }).select().single();

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
      return UserModel(
        id: response.user!.id,
        email: response.user!.email!,
      );
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

  UserModel? getCurrentUser() {
    final user = _client.auth.currentUser;
    if (user != null) {
      return UserModel(id: user.id, email: user.email!);
    }
    return null;
  }
}