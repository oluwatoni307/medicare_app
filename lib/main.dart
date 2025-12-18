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
/// GLOBAL NAVIGATOR KEY (for navigation from anywhere)
/// ------------------------------------------------------
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// ------------------------------------------------------
/// GLOBAL ROUTE OBSERVER (for tracking route lifecycle)
/// ------------------------------------------------------
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

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

    // Setup notification tap handlers (ONLY for background state)
    _setupNotificationTapHandlers();
    debugPrint("✅ Notification tap handlers set up");

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
/// NOTIFICATION TAP HANDLERS
/// ------------------------------------------------------
void _setupNotificationTapHandlers() {
  // ONLY handle notification tap when app is in BACKGROUND
  // (NOT when app was terminated - SplashScreen handles that)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('📱 Notification tapped (app in background)');
    debugPrint('📱 Data: ${message.data}');
    _navigateToSpecialPage(message);
  });

  // ❌ REMOVED: getInitialMessage() handling
  // This was causing the race condition because SplashScreen also checks it
  // Now ONLY SplashScreen handles terminated state notifications
}

void _navigateToSpecialPage(RemoteMessage message) {
  // Extract data from notification
  final medicineId = message.data['medicine_id'];
  final notificationType = message.data['notification_type'];

  debugPrint('🔔 Navigating based on notification type: $notificationType');

  // Navigate to your special page
  if (medicineId != null) {
    navigatorKey.currentState?.pushNamed(AppRoutes.log, arguments: medicineId);
    debugPrint('✅ Navigated to log page for medicine: $medicineId');
  } else {
    // If no medicine_id, navigate to a default page
    navigatorKey.currentState?.pushNamed(AppRoutes.home);
    debugPrint('✅ Navigated to homepage (no medicine_id)');
  }
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
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver], // ← ADDED: Register RouteObserver
        debugShowCheckedModeBanner: false,
        title: 'Medstracker',
        theme: AppTheme.lightTheme,
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.splash,
      ),
    );
  }
}
