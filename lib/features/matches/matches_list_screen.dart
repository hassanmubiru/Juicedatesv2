import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../chat/single_chat_screen.dart';
import '../home/user_profile_screen.dart';
import '../likes/likes_received_tab.dart';
import 'winks_tab.dart';

class MatchesListScreen extends StatefulWidget {
  const MatchesListScreen({super.key});

  @override
  State<MatchesListScreen> createState() => _MatchesListScreenState();
}

class _MatchesListScreenState extends State<MatchesListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: JuiceTheme.primaryTangerine,
          unselectedLabelColor: Colors.grey,
          indicatorColor: JuiceTheme.primaryTangerine,
          tabs: const [
            Tab(icon: Icon(Icons.favorite_rounded), text: 'Matches'),
            Tab(icon: Icon(Icons.star_rounded), text: 'Liked Me'),
            Tab(icon: Icon(Icons.waving_hand_rounded), text: 'Winks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MatchesTab(uid: uid, service: service),
          const LikesReceivedTab(),
          const WinksTab(),
        ],
      ),
    );
  }
}

// ── Matches tab content ───────────────────────────────────────────────────
class _MatchesTab extends StatelessWidget {
  final String uid;
  final FirestoreService service;
  const _MatchesTab({required this.uid, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JuiceMatch>>(
        stream: service.getMatches(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Could not load matches',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            );
          }
          final matches = snapshot.data ?? [];
          if (matches.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final match = matches[index];
              final partnerName = match.getPartnerName(uid);
              final photoUrl = match.getPartnerPhoto(uid);
              final partnerUid = match.getPartnerUid(uid);

              return Card(
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SingleChatScreen(
                        name: partnerName,
                        matchId: match.matchId,
                        partnerUid: partnerUid,
                      ),
                    ),
                  ),
                  leading: GestureDetector(
                    onTap: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(
                            child: CircularProgressIndicator()),
                      );
                      final partnerUser =
                          await service.getUserOnce(partnerUid);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      if (partnerUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              user: partnerUser,
                              sparksScore: match.sparksScore,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Could not load profile')),
                        );
                      }
                    },
                    child: CircleAvatar(
                      backgroundColor: JuiceTheme.primaryTangerine,
                      backgroundImage:
                          photoUrl != null && photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                  title: Text(partnerName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Sparks: ${match.sparksScore.toStringAsFixed(0)}%'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_timeAgo(match.lastMessageTime),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          4,
                          (i) => Icon(
                            i < match.tier
                                ? Icons.battery_charging_full_rounded
                                : Icons.battery_alert_rounded,
                            size: 16,
                            color: i < match.tier
                                ? JuiceTheme.juiceGreen
                                : Colors.grey[300],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No matches yet',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Keep swiping to find your Juice match!',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
