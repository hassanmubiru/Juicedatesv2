// RegisterScreen — replaces the old tab-based email_auth_screen
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../widgets/juice_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  final _service = FirestoreService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await cred.user!.updateDisplayName(_nameCtrl.text.trim());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/quiz');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(e.code))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JuiceDates'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: JuiceTheme.primaryTangerine,
          labelColor: JuiceTheme.primaryTangerine,
          tabs: const [Tab(text: 'Sign In'), Tab(text: 'Sign Up')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSignIn(), _buildSignUp()],
      ),
    );
  }

  Widget _buildSignIn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.favorite_rounded,
              size: 60, color: JuiceTheme.primaryTangerine),
          const SizedBox(height: 24),
          _buildTextField(_emailCtrl, 'Email', Icons.email_rounded,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildPasswordField(),
          const SizedBox(height: 32),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : JuiceButton(
                  onPressed: _signIn,
                  text: 'Sign In',
                  isGradient: true,
                ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _tabController.animateTo(1),
            child: const Text("Don't have an account? Sign up"),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          _buildTextField(_nameCtrl, 'Full Name', Icons.person_rounded),
          const SizedBox(height: 16),
          _buildTextField(_emailCtrl, 'Email', Icons.email_rounded,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildPasswordField(),
          const SizedBox(height: 32),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : JuiceButton(
                  onPressed: _signUp,
                  text: 'Create Account',
                  isGradient: true,
                ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _tabController.animateTo(0),
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: JuiceTheme.primaryTangerine),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordCtrl,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon:
            const Icon(Icons.lock_rounded, color: JuiceTheme.primaryTangerine),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
