import 'package:flutter/material.dart';
import 'package:medicare_app/data/hive_init.dart';
import 'package:medicare_app/features/auth/auth_model.dart';
import 'package:medicare_app/features/auth/service.dart';
import 'package:provider/provider.dart';
import './theme.dart';
import 'features/notifications/daily_notification_worker.dart';
import 'routes.dart' show AppRoutes;
import 'package:supabase_flutter/supabase_flutter.dart';



// this is for demo not functional
String anonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVjZWpya3lkanFqeW1zZXBnc3l6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwOTA5NTksImV4cCI6MjA2NzY2Njk1OX0.G8qm1CH6_dbp6T0SunrBEIzQXOA9lCrCwGTjKwwGfkE";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  //  await initializeWorkManager(); // Function from daily_notification_worker.dart
  
  try {
    await Supabase.initialize(
      url: 'https://ucejrkydjqjymsepgsyz.supabase.co',
      anonKey: anonKey,
    );
  } catch (e) {
    print('Supabase initialization failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return FutureBuilder<UserModel>(
      future: _initializeAuth(authService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        } else if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        } else {
          final user = snapshot.data!;
          print("✅ Successful login: ${user.email}");

          return Provider<UserModel>.value(
            value: snapshot.data!,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Medstracker',
              theme: AppTheme.lightTheme,
              routes: AppRoutes.routes,
              initialRoute: AppRoutes.home,
            ),
          );
        }
      },
    );
  }

  Future<UserModel> _initializeAuth(AuthService authService) async {
    try {
      final user = await authService.signIn(
        'emmanueltoni307@gmail.com',
        'tonyking307',
      );

      final supabase = Supabase.instance.client;

      final userResponse = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (userResponse == null) {
        await supabase.from('users').insert({
          'id': user.id,
          'name': 'Emmanuel Toni',
          'email': user.email,
        });
        print("✅ User added to 'users' table");
      } else {
        print("ℹ️ User already exists in 'users' table");
      }

      return user;
    } catch (e) {
      print('❌ Auth initialization error: $e');
      throw Exception('Authentication failed: $e');
    }
  }
}
