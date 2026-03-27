import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../blocs/auth_bloc.dart';
import '../../core/network/cloudinary_service.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../../main.dart' show themeModeNotifier;
import '../home/user_profile_screen.dart';
import 'passport_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;
  bool _isPremium = false;
  bool _invisibleMode = true;
  bool _newSparks = true;
  bool _showAge = true;
  int _profileViewCount = 0;
  JuiceUser? _user;

  @override
  void initState() {
    super.initState();
    _isDark = themeModeNotifier.value == ThemeMode.dark;
    _loadPrefs();
    _loadUserStatus();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _invisibleMode = prefs.getBool('invisibleMode') ?? false;
        _newSparks = prefs.getBool('newSparks') ?? true;
      });
    }
  }

  Future<void> _loadUserStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await FirestoreService().getUserOnce(uid);
    if (mounted && user != null) {
      setState(() {
        _isPremium = user.isPremium;
        _showAge = user.showAge;
        _user = user;
      });
    }
    // Load profile view count (non-blocking)
    final viewCount = await FirestoreService().getProfileViewCount(uid);
    if (mounted) setState(() => _profileViewCount = viewCount);
  }

  Future<void> _toggleDark(bool val) async {
    setState(() => _isDark = val);
    themeModeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', val);
  }

  Future<void> _toggleInvisible(bool val) async {
    setState(() => _invisibleMode = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('invisibleMode', val);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirestoreService().updateUserProfile(uid, {'invisibleMode': val});
      // Immediately update online presence to reflect the new invisible state
      await FirestoreService().updatePresence(uid, online: !val);
    }
  }

  Future<void> _toggleSparks(bool val) async {
    setState(() => _newSparks = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('newSparks', val);
  }

  Future<void> _toggleShowAge(bool val) async {
    setState(() => _showAge = val);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirestoreService().updateUserProfile(uid, {'showAge': val});
    }
  }

  Future<void> _clearGpsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_city');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS cache cleared.')),
      );
    }
  }

  Future<void> _inviteFriends() async {
    await Share.share(
      '❤️ Join me on JuiceDates — a values-first dating app with an 85% reply rate!\n\nDownload it here: https://juicedates.app',
      subject: 'Join JuiceDates',
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your profile, matches, and all data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirestoreService().deleteAccount(uid);
    await FirebaseAuth.instance.currentUser?.delete();
    if (mounted) {
      context.read<AuthBloc>().add(AuthLoggedOut());
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Future<void> _showProfileViewers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ProfileViewersSheet(
        uid: uid,
        isPremium: _isPremium,
      ),
    );
  }


  Future<void> _showVerificationFlow() async {
    final verificationStatus = _user?.verificationStatus;
    if (verificationStatus == 'verified') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your profile is already verified ✅')),
      );
      return;
    }
    if (verificationStatus == 'pending') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Your verification request is under review. Check back soon!')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _VerificationSheet(
        user: _user!,
        onSubmitted: () {
          // Reload user from Firestore to reflect the pending status
          _loadUserStatus();
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Profile Strength card ──────────────────────────────────────────
          if (_user != null) _ProfileStrengthCard(user: _user!),
          const _SectionHeader(title: 'Account Settings'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/edit-profile'),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Juice Verification'),
            subtitle: Text(
              _user?.verificationStatus == 'verified'
                  ? 'Verified ✅'
                  : _user?.verificationStatus == 'pending'
                      ? 'Under review…'
                      : 'Get a verified badge',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _user == null ? null : _showVerificationFlow,
          ),
          // Profile views
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.visibility_rounded,
                  color: Colors.blue, size: 20),
            ),
            title: const Text('Profile Views'),
            subtitle: Text(
              _profileViewCount == 0
                  ? 'No views yet this week'
                  : '$_profileViewCount ${_profileViewCount == 1 ? 'person' : 'people'} viewed your profile this week',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showProfileViewers(),
          ),
          const _SectionHeader(title: 'Premium'),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: _isPremium ? JuiceTheme.primaryGradient : null,
                color: _isPremium ? null : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isPremium ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isPremium ? Colors.white : JuiceTheme.primaryTangerine,
                size: 20,
              ),
            ),
            title: const Text('Juice Plus+'),
            subtitle: Text(
              _isPremium ? 'Active — all perks unlocked' : 'Unlock Spark Filters & more',
            ),
            trailing: _isPremium
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: JuiceTheme.primaryTangerine.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: JuiceTheme.primaryTangerine,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/premium-paywall'),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.public_rounded,
                  color: Colors.blue, size: 20),
            ),
            title: const Text('Juice Passport'),
            subtitle: Text(
              _user?.passportCity != null
                  ? 'Currently in ${_user?.passportCity}'
                  : 'Change location',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (!_isPremium) {
                Navigator.pushNamed(context, '/premium-paywall');
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PassportScreen()),
                );
              }
            },
          ),
          const _SectionHeader(title: 'Privacy & Safety'),
          SwitchListTile(
            value: _isDark,
            onChanged: _toggleDark,
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          SwitchListTile(
            value: _invisibleMode,
            onChanged: _toggleInvisible,
            title: const Text('Invisible Mode'),
            subtitle: const Text('Hide your online status'),
            secondary: const Icon(Icons.visibility_off_outlined),
          ),
          SwitchListTile(
            value: _showAge,
            onChanged: _toggleShowAge,
            title: const Text('Show My Age'),
            subtitle: const Text('Display age on your profile card'),
            secondary: const Icon(Icons.cake_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.location_off_outlined),
            title: const Text('Clear GPS Cache'),
            subtitle: const Text('Remove saved location data'),
            onTap: _clearGpsCache,
          ),
          const _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            value: _newSparks,
            onChanged: _toggleSparks,
            title: const Text('New Sparks'),
            subtitle: const Text('Notify me when I get a new match'),
            secondary: const Icon(Icons.flash_on_rounded),
          ),
          const _SectionHeader(title: 'Community'),
          ListTile(
            leading: const Icon(Icons.people_alt_outlined),
            title: const Text('Invite Friends'),
            subtitle: const Text('Share JuiceDates with people you know'),
            trailing: const Icon(Icons.share_rounded),
            onTap: _inviteFriends,
          ),
          const _SectionHeader(title: 'Danger Zone'),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: const Text('Delete Account',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently remove your account and data'),
            onTap: _deleteAccount,
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () {
                context.read<AuthBloc>().add(AuthLoggedOut());
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              },
              child: const Text('Logout',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
          const Center(
              child: Text('v1.0.7 (JuiceDates Beta)',
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1),
      ),
    );
  }
}

/// Profile completion strength card — shown at the top of the settings/profile tab.
class _ProfileStrengthCard extends StatelessWidget {
  final JuiceUser user;
  const _ProfileStrengthCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final result = JuiceEngine.computeProfileStrength(user);
    final score = result.score;
    final missing = result.missing;
    final color = score >= 80
        ? JuiceTheme.juiceGreen
        : score >= 50
            ? JuiceTheme.primaryTangerine
            : Colors.red.shade400;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: JuiceTheme.primaryTangerine),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Profile Strength',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Text('$score%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100.0,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...missing.map((hint) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(hint,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    )),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/edit-profile'),
                  child: Text(
                    'Complete your profile →',
                    style: TextStyle(
                        color: JuiceTheme.primaryTangerine,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text('Your profile is complete! 🎉',
                    style: TextStyle(
                        color: JuiceTheme.juiceGreen,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Juice Verification Sheet ─────────────────────────────────────────────────

class _VerificationSheet extends StatefulWidget {
  final JuiceUser user;
  final VoidCallback onSubmitted;
  const _VerificationSheet({required this.user, required this.onSubmitted});

  @override
  State<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<_VerificationSheet> {
  File? _selfie;
  bool _submitting = false;
  final _picker = ImagePicker();
  final _cloudinary = CloudinaryService();
  final _service = FirestoreService();

  Future<void> _pickSelfie() async {
    final picked = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 80, preferredCameraDevice: CameraDevice.front);
    if (picked != null) setState(() => _selfie = File(picked.path));
  }

  Future<void> _submit() async {
    if (_selfie == null) return;
    setState(() => _submitting = true);
    try {
      final url = await _cloudinary.uploadPhoto(
        file: _selfie!,
        publicId:
            'verify_${widget.user.uid}_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _service.submitVerificationRequest(
        uid: widget.user.uid,
        displayName: widget.user.displayName,
        selfieUrl: url,
      );
      widget.onSubmitted();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Verification request submitted! We\'ll review within 24h.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('Juice Verification',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Take a selfie to verify your identity. Our team will review and add a ✅ badge to your profile within 24 hours.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _pickSelfie,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _selfie != null
                            ? JuiceTheme.primaryTangerine
                            : Colors.grey[300]!,
                        width: 2),
                  ),
                  child: _selfie != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_selfie!, fit: BoxFit.cover))
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                size: 36, color: Colors.grey),
                            SizedBox(height: 6),
                            Text('Take Selfie',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: JuiceTheme.primaryTangerine,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: (_selfie == null || _submitting) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit for Verification',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Viewers bottom sheet ───────────────────────────────────────────

class _ProfileViewersSheet extends StatefulWidget {
  final String uid;
  final bool isPremium;
  const _ProfileViewersSheet({required this.uid, required this.isPremium});

  @override
  State<_ProfileViewersSheet> createState() => _ProfileViewersSheetState();
}

class _ProfileViewersSheetState extends State<_ProfileViewersSheet> {
  final _service = FirestoreService();
  List<JuiceUser>? _viewers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final viewers = await _service.getProfileViewers(widget.uid);
    if (mounted) setState(() { _viewers = viewers; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_rounded, color: Colors.blue),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Profile Views',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_viewers == null || _viewers!.isEmpty)
                        ? _buildEmpty()
                        : widget.isPremium
                            ? _buildList(scrollCtrl)
                            : _buildBlurred(scrollCtrl),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('👀', style: TextStyle(fontSize: 56)),
          SizedBox(height: 16),
          Text('No views yet this week',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'When someone views your profile,\nthey\'ll appear here.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList(ScrollController ctrl) {
    return ListView.separated(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      itemCount: _viewers!.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final user = _viewers![i];
        final photo = user.photos.isNotEmpty
            ? user.photos.first
            : (user.photoUrl ?? '');
        return ListTile(
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: JuiceTheme.secondaryCitrus,
            backgroundImage:
                photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          title: Text(
            user.showAge
                ? '${user.displayName}, ${user.age}'
                : user.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(user.city,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(user: user),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBlurred(ScrollController ctrl) {
    return Stack(
      children: [
        IgnorePointer(
          child: GridView.builder(
            controller: ctrl,
            padding: const EdgeInsets.all(12),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.88,
            ),
            itemCount: _viewers!.length,
            itemBuilder: (_, i) {
              final user = _viewers![i];
              final url = user.photos.isNotEmpty
                  ? user.photos.first
                  : (user.photoUrl ?? '');
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ImageFiltered(
                  imageFilter:
                      ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: url.isNotEmpty
                      ? Image.network(url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: JuiceTheme.primaryTangerine
                                  .withValues(alpha: 0.4)))
                      : Container(
                          decoration: BoxDecoration(
                              gradient: JuiceTheme.primaryGradient)),
                ),
              );
            },
          ),
        ),
        // Upgrade CTA overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.95),
                ],
                stops: const [0.3, 0.7],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${_viewers!.length} ${_viewers!.length == 1 ? 'person' : 'people'} viewed your profile',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upgrade to Juice Plus+ to see who they are',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JuiceTheme.primaryTangerine,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/premium-paywall');
                    },
                    child: const Text(
                      'Unlock Viewers — Juice Plus+',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


