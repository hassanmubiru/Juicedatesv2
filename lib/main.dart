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
  final fcmToken = await messaging.getToken();
  if (fcmToken != null) {
    FirebaseAuth.instance.authStateChanges().first.then((user) {
      if (user != null) {
        FirestoreService().updateFcmToken(user.uid, fcmToken);
      }
    });
  }

  runApp(const JuiceDatesApp());
}

class JuiceDatesApp extends StatelessWidget {
  const JuiceDatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc()..add(AuthCheckRequested()),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, themeMode, _) => MaterialApp(
          title: 'JuiceDates',
          theme: JuiceTheme.lightTheme,
          darkTheme: JuiceTheme.darkTheme,
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/email-auth': (context) => const EmailAuthScreen(),
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

