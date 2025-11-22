import 'package:flutter/material.dart';
import 'package:medicare_app/data/hive_init.dart';
import 'package:medicare_app/features/auth/service.dart';
import 'package:medicare_app/features/auth/auth_viewmodel.dart';
import 'package:medicare_app/features/notifications/service.dart';
import 'package:provider/provider.dart';
import './theme.dart';
import 'routes.dart' show AppRoutes;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:medicare_app/firebase_options.dart';

/// ------------------------------------------------------
/// 1. BACKGROUND NOTIFICATION HANDLER
/// ------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("📩 Background message received: ${message.messageId}");
}

String anonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVjZWpya3lkanFqeW1zZXBnc3l6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwOTA5NTksImV4cCI6MjA2NzY2Njk1OX0.G8qm1CH6_dbp6T0SunrBEIzQXOA9lCrCwGTjKwwGfkE";

String supabaseUrl = "https://ucejrkydjqjymsepgsyz.supabase.co";

/// ------------------------------------------------------
/// 2. MAIN ENTRY
/// ------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background handler early
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    // Initialize Firebase BEFORE NotificationService
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');

    // Initialize Hive
    await initHive();
    debugPrint('✅ Hive initialized');

    // Initialize Supabase
    await Supabase.initialize(url: supabaseUrl, anonKey: anonKey);
    debugPrint('✅ Supabase initialized');

    // Initialize Notification Service (gets token & saves to DB)
    await NotificationService.instance.init();
    debugPrint("✅ NotificationService initialized");

    // (Optional) background/periodic worker registration
    try {
      // await registerDailyWorker();
      debugPrint("⚙️ Daily worker registered");
    } catch (e) {
      debugPrint("⚠️ Daily worker registration failed: $e");
    }

    debugPrint("🚀 App initialized successfully");
  } catch (e) {
    debugPrint("❌ Initialization error: $e");
  }

  runApp(const MyApp());
}

/// ------------------------------------------------------
/// 3. APP WIDGET
/// ------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) =>
              AuthViewModel(Provider.of<AuthService>(context, listen: false)),
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
