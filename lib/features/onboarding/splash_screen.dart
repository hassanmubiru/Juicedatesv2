import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import '../../blocs/auth_bloc.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterSplash();
  }

  _navigateAfterSplash() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final bloc = context.read<AuthBloc>();

    // Wait until auth stream emits a definite state (not still loading)
    AuthState state = bloc.state;
    if (state is AuthInitial || state is AuthInProgress) {
      state = await bloc.stream
          .firstWhere((s) => s is! AuthInitial && s is! AuthInProgress);
    }
    if (!mounted) return;

    if (state is AuthAuthenticated) {
      final uid = state.user.uid;
      final user = await FirestoreService().getUserOnce(uid);
      if (!mounted) return;
      // Route to quiz/profile-setup if onboarding not completed
      if (user == null || user.juiceSummary.isEmpty) {
        Navigator.pushReplacementNamed(context, '/quiz');
      } else if (user.isAdmin) {
        // Admins land directly in the Admin Panel
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie animation placeholder
            SizedBox(
              height: 200,
              width: 200,
              child: Lottie.asset(
                'assets/lottie/juice_loading.json',
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.local_drink_rounded,
                    size: 100,
                    color: Colors.white,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'JuiceDates',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const Text(
              'Values Dating Revolution',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
