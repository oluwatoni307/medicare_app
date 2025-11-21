import 'package:flutter/foundation.dart' show kIsWeb;  // ADD THIS IMPORT
import 'package:flutter/material.dart';
import 'package:medicare_app/data/hive_init.dart';
import 'package:medicare_app/features/auth/service.dart';
import 'package:medicare_app/features/auth/auth_viewmodel.dart';
import 'package:medicare_app/features/notifications/service.dart';
import 'package:provider/provider.dart';
import './theme.dart';
import 'routes.dart' show AppRoutes;
import 'package:supabase_flutter/supabase_flutter.dart';

String anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVjZWpya3lkanFqeW1zZXBnc3l6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwOTA5NTksImV4cCI6MjA2NzY2Njk1OX0.G8qm1CH6_dbp6T0SunrBEIzQXOA9lCrCwGTjKwwGfkE";
String supabaseUrl = "https://ucejrkydjqjymsepgsyz.supabase.co";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  WidgetsBinding.instance.deferFirstFrame();
  
  try {
    // Initialize Hive first
    await initHive();
    print('✅ Hive initialized successfully');
    
    // Initialize Supabase BEFORE notifications
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: anonKey,
    );
    print('✅ Supabase initialized successfully');
    
    // Initialize notifications ONLY on mobile/desktop (NOT on web)
    if (!kIsWeb) {
      print('📱 Initialising notification service...');
      await NotificationService.instance.init();
      print('✅ Notification service initialized');
    } else {
      print('⚠️ Web platform detected - notifications disabled');
    }
    
    // Register daily worker (with error handling)
    if (!kIsWeb) {
      try {
        // await registerDailyWorker();
        print('✅ Daily worker registered successfully');
      } catch (e) {
        print('⚠️ Daily worker registration failed: $e');
      }
    }
    
    print('✅ App initialization completed successfully');
    
  } catch (e, stackTrace) {
    print('❌ App initialization failed: $e');
    print(stackTrace);
  }

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
        initialRoute: AppRoutes.splash,
      ),
    );
  }
}