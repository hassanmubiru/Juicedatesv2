import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../widgets/juice_button.dart';

class PremiumFiltersScreen extends StatefulWidget {
  const PremiumFiltersScreen({super.key});

  @override
  State<PremiumFiltersScreen> createState() => _PremiumFiltersScreenState();
}

class _PremiumFiltersScreenState extends State<PremiumFiltersScreen> {
  bool _isPremium = false;
  bool _loading = true;

  // Discovery settings (persisted to Firestore)
  double _maxDistance = 100;
  RangeValues _ageRange = const RangeValues(18, 50);
  String _showGender = 'everyone';
  String? _passportCity;
  final _passportCtrl = TextEditingController();

  // Core value & advanced filters (premium only; local-only for now)
  final Set<String> _selectedValues = {};
  final Set<String> _selectedAdvanced = {};

  static const _coreValues = [
    'Family Focused', 'Career Driven', 'Lifestyle Match',
    'Faith-Oriented', 'Adventure Seeker',
  ];
  static const _advanced = ['Voice Only', 'Video Ready', 'Verified', 'New to JuiceDates'];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _passportCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await FirestoreService().getUserOnce(uid);
    if (mounted) {
      setState(() {
        _isPremium = user?.isPremium ?? false;
        _maxDistance = (user?.maxDistance ?? 100).clamp(10, 200);
        final min = (user?.ageRangeMin ?? 18).toDouble().clamp(18.0, 80.0);
        final max = (user?.ageRangeMax ?? 50).toDouble().clamp(18.0, 80.0);
        _ageRange = RangeValues(min, max.clamp(min + 2, 80.0));
        _showGender = user?.showGender ?? 'everyone';
        _passportCity = user?.passportCity;
        if (_passportCity != null) _passportCtrl.text = _passportCity!;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final passport = _passportCtrl.text.trim();
    await FirestoreService().updateUserProfile(uid, {
      'maxDistance': _maxDistance,
      'ageRangeMin': _ageRange.start.round(),
      'ageRangeMax': _ageRange.end.round(),
      'showGender': _showGender,
      'passportCity': passport.isEmpty ? null : passport,
    });
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discovery settings saved!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discovery Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isPremium
              ? _buildFilters()
              : _buildLockedOverlay(),
    );
  }

  // ── Premium: functional discovery settings ────────────────────────────────
  Widget _buildFilters() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Juice Plus+ badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: JuiceTheme.primaryTangerine.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded,
                  color: JuiceTheme.primaryTangerine, size: 14),
              SizedBox(width: 4),
              Text(
                'Juice Plus+ Active',
                style: TextStyle(
                  color: JuiceTheme.primaryTangerine,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Show me ──────────────────────────────────────────────────────────
        const _SectionLabel(label: 'Show Me'),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'everyone', label: Text('Everyone')),
            ButtonSegment(value: 'men', label: Text('Men')),
            ButtonSegment(value: 'women', label: Text('Women')),
          ],
          selected: {_showGender},
          onSelectionChanged: (s) => setState(() => _showGender = s.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor:
                JuiceTheme.primaryTangerine.withValues(alpha: 0.15),
            selectedForegroundColor: JuiceTheme.primaryTangerine,
          ),
        ),

        const SizedBox(height: 28),

        // ── Age range ─────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel(label: 'Age Range'),
            Text(
              '${_ageRange.start.round()} – ${_ageRange.end.round()}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: JuiceTheme.primaryTangerine),
            ),
          ],
        ),
        RangeSlider(
          values: _ageRange,
          min: 18,
          max: 80,
          divisions: 62,
          activeColor: JuiceTheme.primaryTangerine,
          inactiveColor: JuiceTheme.primaryTangerine.withValues(alpha: 0.2),
          labels: RangeLabels(
            '${_ageRange.start.round()}',
            '${_ageRange.end.round()}',
          ),
          onChanged: (v) {
            if (v.end - v.start < 2) return;
            setState(() => _ageRange = v);
          },
        ),

        const SizedBox(height: 20),

        // ── Max distance ──────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel(label: 'Maximum Distance'),
            Text(
              _maxDistance >= 200 ? 'Anywhere' : '${_maxDistance.round()} km',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: JuiceTheme.primaryTangerine),
            ),
          ],
        ),
        Slider(
          value: _maxDistance,
          min: 10,
          max: 200,
          divisions: 19,
          activeColor: JuiceTheme.primaryTangerine,
          inactiveColor: JuiceTheme.primaryTangerine.withValues(alpha: 0.2),
          label: _maxDistance >= 200 ? 'Anywhere' : '${_maxDistance.round()} km',
          onChanged: (v) => setState(() => _maxDistance = v),
        ),

        const SizedBox(height: 20),

        // ── Passport (browse another city) ────────────────────────────────────
        const _SectionLabel(label: 'Passport — Browse Another City'),
        const SizedBox(height: 8),
        TextField(
          controller: _passportCtrl,
          decoration: InputDecoration(
            hintText: 'Enter a city to explore',
            prefixIcon: const Icon(Icons.flight_takeoff_rounded,
                color: JuiceTheme.primaryTangerine),
            suffixIcon: _passportCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                    onPressed: () {
                      _passportCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_passportCtrl.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Browsing profiles in "${_passportCtrl.text}"',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 28),

        // ── Core Values ───────────────────────────────────────────────────────
        _buildFilterGroup(
          'Core Values',
          _coreValues,
          _selectedValues,
          (opt) => setState(() => _selectedValues.contains(opt)
              ? _selectedValues.remove(opt)
              : _selectedValues.add(opt)),
        ),
        const SizedBox(height: 24),
        _buildFilterGroup(
          'Advanced',
          _advanced,
          _selectedAdvanced,
          (opt) => setState(() => _selectedAdvanced.contains(opt)
              ? _selectedAdvanced.remove(opt)
              : _selectedAdvanced.add(opt)),
        ),

        const SizedBox(height: 32),
        JuiceButton(onPressed: _save, text: 'Save Settings', isGradient: true),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildFilterGroup(
    String title,
    List<String> options,
    Set<String> selected,
    void Function(String) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: title),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (_) => onToggle(opt),
              selectedColor:
                  JuiceTheme.primaryTangerine.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected
                    ? JuiceTheme.primaryTangerine
                    : Colors.grey[300]!,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Non-premium: locked overlay ───────────────────────────────────────────
  Widget _buildLockedOverlay() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildPreviewGroup('Show Me', ['Everyone', 'Men', 'Women']),
            const SizedBox(height: 24),
            _buildPreviewGroup('Age Range', ['18 – 35', '25 – 50']),
            const SizedBox(height: 24),
            _buildPreviewGroup('Distance', ['Anywhere', '50 km']),
            const SizedBox(height: 24),
            _buildPreviewGroup('Passport', ['Browse another city']),
            const SizedBox(height: 24),
            _buildPreviewGroup('Core Values', ['Family Focused', 'Career Driven']),
          ],
        ),
        Container(
          color: Colors.white.withValues(alpha: 0.85),
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              elevation: 12,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 60, color: JuiceTheme.primaryTangerine),
                    const SizedBox(height: 24),
                    const Text(
                      'Unlock Discovery Settings',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Set your age range, distance, gender preference, and even browse profiles in another city with Passport.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    JuiceButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/premium-paywall'),
                      text: 'Get Juice Plus+',
                      isGradient: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewGroup(String title, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: title),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: options.map((opt) => Chip(label: Text(opt))).toList(),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1),
    );
  }
}

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await FirestoreService().getUserOnce(uid);
    if (mounted) {
      setState(() {
        _isPremium = user?.isPremium ?? false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spark Filters')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isPremium
              ? _buildFilters()
              : _buildLockedOverlay(),
    );
  }

  // ── Premium: actual functional filter UI ──────────────────────────────
  Widget _buildFilters() {
    final values = [
      'Family Focused', 'Career Driven', 'Lifestyle Match',
      'Faith-Oriented', 'Adventure Seeker',
    ];
    final distances = ['Anywhere', '100 km', '50 km', '25 km', '10 km'];
    final advanced = ['Voice Only', 'Video Ready', 'Verified', 'New to JuiceDates'];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: JuiceTheme.primaryTangerine.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded,
                  color: JuiceTheme.primaryTangerine, size: 14),
              SizedBox(width: 4),
              Text(
                'Juice Plus+ Active',
                style: TextStyle(
                  color: JuiceTheme.primaryTangerine,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildFilterGroup(
          'Core Values',
          values,
          _selectedValues,
          (opt) => setState(() => _selectedValues.contains(opt)
              ? _selectedValues.remove(opt)
              : _selectedValues.add(opt)),
        ),
        const SizedBox(height: 24),
        const Text('Distance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: distances.map((d) {
            final selected = _selectedDistance == d;
            return ChoiceChip(
              label: Text(d),
              selected: selected,
              onSelected: (_) => setState(() => _selectedDistance = d),
              selectedColor:
                  JuiceTheme.primaryTangerine.withValues(alpha: 0.2),
              side: BorderSide(
                color: selected
                    ? JuiceTheme.primaryTangerine
                    : Colors.grey[300]!,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildFilterGroup(
          'Advanced',
          advanced,
          _selectedAdvanced,
          (opt) => setState(() => _selectedAdvanced.contains(opt)
              ? _selectedAdvanced.remove(opt)
              : _selectedAdvanced.add(opt)),
        ),
        const SizedBox(height: 32),
        JuiceButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Filters applied!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          text: 'Apply Filters',
          isGradient: true,
        ),
      ],
    );
  }

  Widget _buildFilterGroup(
    String title,
    List<String> options,
    Set<String> selected,
    void Function(String) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (_) => onToggle(opt),
              selectedColor:
                  JuiceTheme.primaryTangerine.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected
                    ? JuiceTheme.primaryTangerine
                    : Colors.grey[300]!,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Non-premium: locked overlay ───────────────────────────────────────
  Widget _buildLockedOverlay() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildPreviewGroup(
                'Core Values', ['Family Focused', 'Career Driven', 'Lifestyle']),
            const SizedBox(height: 24),
            _buildPreviewGroup('Distance', ['Anywhere', '50 km', '10 km']),
            const SizedBox(height: 24),
            _buildPreviewGroup(
                'Advanced', ['Voice Only', 'Video Ready', 'Verified']),
          ],
        ),
        Container(
          color: Colors.white.withValues(alpha: 0.85),
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              elevation: 12,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 60, color: JuiceTheme.primaryTangerine),
                    const SizedBox(height: 24),
                    const Text(
                      'Unlock Spark Filters',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '85% of people find their perfect match faster with Juice Plus+.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    JuiceButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/premium-paywall'),
                      text: 'Get Juice Plus+',
                      isGradient: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewGroup(String title, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: options.map((opt) => Chip(label: Text(opt))).toList(),
        ),
      ],
    );
  }
}
