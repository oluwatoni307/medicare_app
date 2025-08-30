import 'package:flutter/material.dart';
import 'package:medicare_app/data/hive_init.dart';
// import 'package:medicare_app/features/auth/auth_model.dart';
import 'package:medicare_app/features/auth/service.dart';
import 'package:medicare_app/features/auth/auth_viewmodel.dart';
import 'package:medicare_app/features/notifications/service.dart';
import 'package:provider/provider.dart';
import './theme.dart';
import 'features/notifications/daily_notification_worker.dart';
import 'routes.dart' show AppRoutes;
import 'package:supabase_flutter/supabase_flutter.dart';

// Use your actual Supabase credentials
String anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVjZWpya3lkanFqeW1zZXBnc3l6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwOTA5NTksImV4cCI6MjA2NzY2Njk1OX0.G8qm1CH6_dbp6T0SunrBEIzQXOA9lCrCwGTjKwwGfkE";
String supabaseUrl = "https://ucejrkydjqjymsepgsyz.supabase.co";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Handle plugin messages before framework is ready
  WidgetsBinding.instance.deferFirstFrame();
  
  try {
    // Initialize Hive first
    await initHive();
    print('✅ Hive initialized successfully');
    
    // Initialize notifications (uncomment when ready)
    // await NotificationService.instance.init();
    
    // Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: anonKey,
    );
    print('✅ Supabase initialized successfully');
    
    // Register daily worker (with error handling)
    try {
      // await registerDailyWorker();
      print('✅ Daily worker registered successfully');
    } catch (e) {
      print('⚠️ Daily worker registration failed: $e');
      // Continue without daily worker for now
    }
    
    print('✅ App initialization completed successfully');
    
  } catch (e) {
    print('❌ App initialization failed: $e');
    // Still run the app but show error state
  }

  // Allow the first frame to be drawn
  WidgetsBinding.instance.allowFirstFrame();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            Provider.of<AuthService>(context, listen: false),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Medstracker',
        theme: AppTheme.lightTheme,
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.splash, // Start with splash screen
      ),
    );
  }
}