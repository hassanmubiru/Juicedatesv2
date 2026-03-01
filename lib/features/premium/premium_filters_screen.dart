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

  // Selected filter state (only active when premium)
  String _selectedDistance = 'Anywhere';
  final Set<String> _selectedValues = {};
  final Set<String> _selectedAdvanced = {};

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
