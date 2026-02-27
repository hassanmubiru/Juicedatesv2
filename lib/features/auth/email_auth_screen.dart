import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../widgets/juice_button.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  final _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final existing = await _service.getUserOnce(uid);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
          context, existing == null ? '/quiz' : '/home');
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
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
      _showError(_friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return 'Authentication failed. Please try again.';
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
