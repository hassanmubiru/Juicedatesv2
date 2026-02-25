import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/theme/juice_theme.dart';
import '../../core/network/firestore_service.dart';
import '../../widgets/juice_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  final _service = FirestoreService();

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn(
        serverClientId:
            '408134384062-lmpotnn8c3n1frccsgqm1f6p7qpdu4vu.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user!;

      final existing = await _service.getUserOnce(user.uid);
      if (!mounted) return;
      if (existing == null) {
        Navigator.pushReplacementNamed(context, '/quiz');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Icon(
              Icons.favorite_rounded,
              size: 80,
              color: JuiceTheme.primaryTangerine,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to\nJuiceDates',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Find someone who shares your values, not just your hobbies.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const Spacer(),
            JuiceButton(
              onPressed: () => Navigator.pushNamed(context, '/quiz'),
              text: 'Sign Up with Email',
              isGradient: true,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              OutlinedButton.icon(
                onPressed: _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 30),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: JuiceTheme.primaryTangerine),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
