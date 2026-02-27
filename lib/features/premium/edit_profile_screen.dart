import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _service = FirestoreService();
  final _picker = ImagePicker();

  JuiceUser? _user;
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _bioCtrl;
  List<String> _interests = [];
  List<String?> _photoUrls = List.filled(6, null);
  final List<File?> _newPhotos = List.filled(6, null);

  final List<String> _availableInterests = [
    'Hiking', 'Reading', 'Cooking', 'Travel', 'Gaming', 'Music',
    'Art', 'Fitness', 'Photography', 'Movies', 'Dancing', 'Yoga',
    'Tech', 'Entrepreneurship', 'Family', 'Faith', 'Volunteering',
    'Fashion', 'Sports', 'Coffee', 'Wine', 'Pets', 'Nature',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await _service.getUserOnce(uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _nameCtrl = TextEditingController(text: user?.displayName ?? '');
      _cityCtrl = TextEditingController(text: user?.city ?? 'Kampala');
      _ageCtrl = TextEditingController(text: (user?.age ?? 25).toString());
      _bioCtrl = TextEditingController(text: user?.bio ?? '');
      _interests = List<String>.from(user?.interests ?? []);
      _photoUrls = List.generate(6, (i) =>
          i < (user?.photos.length ?? 0) ? user!.photos[i] : null);
      _loading = false;
    });
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
        source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      _newPhotos[index] = File(picked.path);
      _photoUrls[index] = null; // will be replaced by new upload
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      // Upload any new photos
      final updatedUrls = <String>[];
      for (int i = 0; i < 6; i++) {
        if (_newPhotos[i] != null) {
          final url = await _service.uploadPhoto(uid, _newPhotos[i]!, i);
          updatedUrls.add(url);
        } else if (_photoUrls[i] != null) {
          updatedUrls.add(_photoUrls[i]!);
        }
      }

      await _service.updateUserProfile(uid, {
        'displayName': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()) ?? _user?.age ?? 25,
        'bio': _bioCtrl.text.trim(),
        'interests': _interests,
        'photos': updatedUrls,
        if (updatedUrls.isNotEmpty) 'photoUrl': updatedUrls.first,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _ageCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Photos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: List.generate(6, (i) {
                final newFile = _newPhotos[i];
                final existingUrl = _photoUrls[i];
                return GestureDetector(
                  onTap: () => _pickPhoto(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      image: newFile != null
                          ? DecorationImage(
                              image: FileImage(newFile), fit: BoxFit.cover)
                          : existingUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(existingUrl),
                                  fit: BoxFit.cover)
                              : null,
                    ),
                    child: (newFile == null && existingUrl == null)
                        ? const Icon(Icons.add_a_photo_rounded,
                            color: Colors.grey)
                        : Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.white70,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.edit_rounded,
                                  size: 18,
                                  color: JuiceTheme.primaryTangerine),
                            ),
                          ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            _buildField(_nameCtrl, 'Display Name', Icons.person_rounded),
            const SizedBox(height: 16),
            _buildField(_cityCtrl, 'City', Icons.location_on_rounded),
            const SizedBox(height: 16),
            _buildField(_ageCtrl, 'Age', Icons.cake_rounded,
                type: TextInputType.number),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell people a little about yourself...',
                prefixIcon: const Icon(Icons.edit_note_rounded,
                    color: JuiceTheme.primaryTangerine),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Interests',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableInterests.map((interest) {
                final selected = _interests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: selected,
                  selectedColor: JuiceTheme.primaryTangerine.withValues(alpha: 0.2),
                  checkmarkColor: JuiceTheme.primaryTangerine,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        if (_interests.length < 8) _interests.add(interest);
                      } else {
                        _interests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : JuiceButton(
                    onPressed: _save,
                    text: 'Save Changes',
                    isGradient: true,
                  ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: JuiceTheme.primaryTangerine),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
