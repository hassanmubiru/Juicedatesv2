import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/firestore_service.dart';
import '../../core/utils/juice_engine.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_button.dart';
import '../../core/theme/juice_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _service = FirestoreService();
  final _cityController = TextEditingController(text: 'Kampala');
  final _ageController = TextEditingController(text: '25');
  final _picker = ImagePicker();
  final List<File?> _photos = List.filled(6, null);
  bool _saving = false;

  Future<void> _pickPhoto(int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _photos[index] = File(picked.path));
  }

  Future<void> _saveProfile() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final profile =
        ModalRoute.of(context)?.settings.arguments as JuiceProfile? ??
            JuiceProfile(
                family: 0.5,
                career: 0.5,
                lifestyle: 0.5,
                ethics: 0.5,
                fun: 0.5);

    final scores = {
      'Family': profile.family,
      'Career': profile.career,
      'Lifestyle': profile.lifestyle,
      'Ethics': profile.ethics,
      'Fun': profile.fun,
    };
    final dominant =
        scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final summary = '${dominant.key} Juice Master '
        '(${(scores.values.reduce((a, b) => a + b) / scores.length * 100).round()}%)';

    setState(() => _saving = true);
    try {
      // Upload photos to Firebase Storage
      final uploadedUrls = <String>[];
      for (int i = 0; i < _photos.length; i++) {
        if (_photos[i] != null) {
          final url = await _service.uploadPhoto(
              firebaseUser.uid, _photos[i]!, i);
          uploadedUrls.add(url);
        }
      }

      final juiceUser = JuiceUser(
        uid: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? 'JuiceUser',
        age: int.tryParse(_ageController.text.trim()) ?? 25,
        email: firebaseUser.email,
        photoUrl: uploadedUrls.isNotEmpty
            ? uploadedUrls.first
            : firebaseUser.photoURL,
        photos: uploadedUrls,
        city: _cityController.text.trim(),
        juiceProfile: profile,
        juiceSummary: summary,
      );
      await _service.createUser(juiceUser);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add your best photos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: List.generate(6, (index) {
                final photo = _photos[index];
                return GestureDetector(
                  onTap: () => _pickPhoto(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      image: photo != null
                          ? DecorationImage(
                              image: FileImage(photo),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: photo == null
                        ? const Icon(Icons.add_a_photo_rounded,
                            color: Colors.grey)
                        : Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white70,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  size: 18,
                                  color: JuiceTheme.primaryTangerine),
                            ),
                          ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            const Text(
              'Your Voice Juice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Record a 10s intro to boost matching by 20%'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JuiceTheme.primaryTangerine.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic_rounded, color: JuiceTheme.primaryTangerine),
                  const SizedBox(width: 16),
                  const Text('Introduction Voice Note'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Where are you?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'City',
                prefixIcon: const Icon(Icons.location_on_rounded,
                    color: JuiceTheme.primaryTangerine),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your age',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Age',
                prefixIcon: const Icon(Icons.cake_rounded,
                    color: JuiceTheme.primaryTangerine),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 48),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : JuiceButton(
                    onPressed: _saveProfile,
                    text: 'Save & Continue',
                    isGradient: true,
                  ),
          ],
        ),
      ),
    );
  }
}
