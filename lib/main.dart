import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/juice_theme.dart';
import 'blocs/auth_bloc.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_screen.dart';
import 'features/onboarding/quiz_screen.dart';

import 'features/onboarding/juice_summary.dart';
import 'features/onboarding/profile_setup.dart';
import 'features/premium/premium_filters_screen.dart';
import 'features/premium/settings_screen.dart';
import 'features/calling/video_call_screen.dart';
import 'features/calling/audio_call_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const JuiceDatesApp());
}

class JuiceDatesApp extends StatelessWidget {
  const JuiceDatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc()..add(AuthCheckRequested()),
      child: MaterialApp(
        title: 'JuiceDates',
        theme: JuiceTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/quiz': (context) => const QuizScreen(),
          '/summary': (context) => const JuiceSummaryScreen(),
          '/profile-setup': (context) => const ProfileSetupScreen(),
          '/home': (context) => const MainScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/filters': (context) => const PremiumFiltersScreen(),
          '/video-call': (context) => const VideoCallScreen(),
          '/audio-call': (context) => const AudioCallScreen(),
        },
      ),
    );
  }
}
