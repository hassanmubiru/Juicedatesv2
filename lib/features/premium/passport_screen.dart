import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';

class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _service = FirestoreService();
  bool _loading = false;
  String? _currentPassport;
  
  // Mock results for demonstration — in production, this would call a Places API
  final List<String> _allCities = [
    'New York, USA', 'London, UK', 'Tokyo, Japan', 'Paris, France', 'Dubai, UAE',
    'Los Angeles, USA', 'Toronto, Canada', 'Sydney, Australia', 'Berlin, Germany',
    'Milan, Italy', 'Cape Town, South Africa', 'Nairobi, Kenya', 'Kampala, Uganda',
    'Lagos, Nigeria', 'Accra, Ghana', 'Johannesburg, South Africa', 'Kigali, Rwanda'
  ];
  List<String> _results = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _results = _allCities
          .where((city) => city.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _loadCurrentPath() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await _service.getUserOnce(uid);
    if (mounted) setState(() => _currentPassport = user?.passportCity);
  }

  Future<void> _setPassport(String city) async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _service.updateUserProfile(uid, {'passportCity': city});
      if (mounted) {
        setState(() {
          _currentPassport = city;
          _loading = false;
          _searchController.clear();
          _results = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Passported to $city! ✈️'), backgroundColor: JuiceTheme.primaryTangerine),
        );
      }
    }
  }

  Future<void> _clearPassport() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _service.updateUserProfile(uid, {'passportCity': null});
      if (mounted) {
        setState(() {
          _currentPassport = null;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Returned to your local location.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Juice Passport')),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: JuiceTheme.primaryGradient,
            ),
            child: Column(
              children: [
                const Icon(Icons.public_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Explore Any City',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Change your location to find matches anywhere in the world.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // ── Search & Current State ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_currentPassport != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: JuiceTheme.primaryTangerine.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: JuiceTheme.primaryTangerine.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: JuiceTheme.primaryTangerine),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Current Location', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(_currentPassport!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _clearPassport,
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for a city...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search Results ────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(child: Text('No cities found', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final city = _results[index];
                          return ListTile(
                            leading: const Icon(Icons.location_city_rounded, color: Colors.grey),
                            title: Text(city),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _setPassport(city),
                          );
                        },
                      ),
          ),
          
          if (_results.isEmpty && _searchController.text.isEmpty)
            Expanded(
              child: Opacity(
                opacity: 0.5,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, size: 64),
                      const SizedBox(height: 16),
                      const Text('Your next match could be anywhere!'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
