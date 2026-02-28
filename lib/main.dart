import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme/juice_theme.dart';
import 'core/network/firestore_service.dart';
import 'blocs/auth_bloc.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/email_auth_screen.dart';
import 'features/home/main_screen.dart';
import 'features/onboarding/quiz_screen.dart';
import 'features/onboarding/juice_summary.dart';
import 'features/onboarding/profile_setup.dart';
import 'features/premium/premium_filters_screen.dart';
import 'features/premium/settings_screen.dart';
import 'features/premium/edit_profile_screen.dart';
import 'features/calling/video_call_screen.dart';
import 'features/calling/audio_call_screen.dart';
import 'features/admin/admin_shell.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('darkMode') ?? false;
  themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // Firebase Messaging setup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Subscribe to topic for admin announcements (all users receive broadcasts)
  await messaging.subscribeToTopic('all_users');

  // Store FCM token for direct push (match / message notifications)
  final fcmToken = await messaging.getToken();
  if (fcmToken != null) {
    FirebaseAuth.instance.authStateChanges().first.then((user) {
      if (user != null) {
        FirestoreService().updateFcmToken(user.uid, fcmToken);
      }
    });
  }

  // Refresh token handler
  messaging.onTokenRefresh.listen((newToken) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) FirestoreService().updateFcmToken(user.uid, newToken);
  });

  runApp(const JuiceDatesApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class JuiceDatesApp extends StatefulWidget {
  const JuiceDatesApp({super.key});

  @override
  State<JuiceDatesApp> createState() => _JuiceDatesAppState();
}

class _JuiceDatesAppState extends State<JuiceDatesApp> {
  @override
  void initState() {
    super.initState();
    _setupForegroundMessages();
    _setupNotificationTap();
    _subscribeAdminTopicIfNeeded();
  }

  /// Subscribe to the "admins" FCM topic if the current user is an admin,
  /// so they receive ban notifications from Cloud Functions.
  void _subscribeAdminTopicIfNeeded() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      final juiceUser = await FirestoreService().getUserOnce(user.uid);
      if (juiceUser?.isAdmin == true) {
        await FirebaseMessaging.instance.subscribeToTopic('admins');
      }
    });
  }

  /// Show an in-app banner when a push arrives while the app is open.
  void _setupForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.title ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (notification.body != null) Text(notification.body!),
            ],
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () =>
                _handleNotificationData(message.data),
          ),
        ),
      );
    });
  }

  /// Navigate to the correct screen when the user taps a notification
  /// that opened the app from background/terminated.
  void _setupNotificationTap() {
    // App opened from a terminated state via notification
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
      if (message != null) _handleNotificationData(message.data);
    });

    // App resumed from background via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationData(message.data);
    });
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (type) {
      case 'match':
      case 'message':
        // Navigate to the matches list; deep-link into the specific chat
        // if a matchId is provided.
        nav.pushNamed('/home');
        break;
      case 'ban':
        // Admins: open admin panel
        nav.pushNamed('/admin');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc()..add(AuthCheckRequested()),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, themeMode, _) => MaterialApp(
          title: 'JuiceDates',
          navigatorKey: navigatorKey,
          theme: JuiceTheme.lightTheme,
          darkTheme: JuiceTheme.darkTheme,
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/quiz': (context) => const QuizScreen(),
            '/summary': (context) => const JuiceSummaryScreen(),
            '/profile-setup': (context) => const ProfileSetupScreen(),
            '/home': (context) => const MainScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/edit-profile': (context) => const EditProfileScreen(),
            '/filters': (context) => const PremiumFiltersScreen(),
            '/video-call': (context) => const VideoCallScreen(),
            '/audio-call': (context) => const AudioCallScreen(),
            '/admin': (context) => const AdminShell(),
          },
        ),
      ),
    );
  }
}

