import 'service.dart';

void main() async {
  final authService = AuthService();
  try {
    final user = await authService.signIn('emmanueltoni307@gmail.com', 'tonyking307');
    print('Signed in: ${user.email}');
  } catch (e) {
    print('Error: $e');
  }
}