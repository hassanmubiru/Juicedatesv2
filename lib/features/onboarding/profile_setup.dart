import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/firestore_service.dart';
import '../../core/utils/juice_engine.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_button.dart';
import '../../core/theme/juice_theme.dart';

const List<String> _kInterests = [
  'Hiking', 'Reading', 'Cooking', 'Travel', 'Gaming', 'Music',
  'Art', 'Fitness', 'Photography', 'Movies', 'Dancing', 'Yoga',
  'Tech', 'Entrepreneurship', 'Family', 'Faith', 'Volunteering',
  'Fashion', 'Sports', 'Coffee', 'Pets', 'Nature',
];

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _service = FirestoreService();
  late final TextEditingController _nameController;
  final _cityController = TextEditingController(text: 'Kampala');
  final _ageController = TextEditingController(text: '25');
  final _bioController = TextEditingController();
  final _picker = ImagePicker();
  final List<File?> _photos = List.filled(6, null);
  final List<String> _selectedInterests = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fbUser = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: fbUser?.displayName ?? '');
  }

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
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    if (name.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name and city.')),
      );
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

      await firebaseUser.updateDisplayName(name);
      final juiceUser = JuiceUser(
        uid: firebaseUser.uid,
        displayName: name,
        age: int.tryParse(_ageController.text.trim()) ?? 25,
        email: firebaseUser.email,
        photoUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
        photos: uploadedUrls,
        city: city,
        juiceProfile: profile,
        juiceSummary: summary,
        bio: _bioController.text.trim(),
        interests: _selectedInterests,
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
    _nameController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _bioController.dispose();
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
            const Text('Your Interests',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Pick up to 8 that best describe you',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kInterests.map((interest) {
                final selected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: selected,
                  selectedColor:
                      JuiceTheme.primaryTangerine.withValues(alpha: 0.2),
                  checkmarkColor: JuiceTheme.primaryTangerine,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        if (_selectedInterests.length < 8) {
                          _selectedInterests.add(interest);
                        }
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
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
