import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../home/user_profile_screen.dart';
import '../matches/winks_tab.dart';

/// Hookup4u-style Notifications screen.
/// Shows new matches (with "NEW" badge for unread) and recent winks.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Matches'),
              Tab(text: 'Winks'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MatchNotificationsTab(uid: uid),
            const WinksTab(),
          ],
        ),
      ),
    );
  }
}

class _MatchNotificationsTab extends StatelessWidget {
  final String uid;
  const _MatchNotificationsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return StreamBuilder<List<JuiceMatch>>(
      stream: service.getMatches(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🍊', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text('No matches yet',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Keep swiping to find your perfect match!',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: matches.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 80),
          itemBuilder: (context, i) {
            final match = matches[i];
            return _MatchNotificationTile(match: match, myUid: uid);
          },
        );
      },
    );
  }
}

class _MatchNotificationTile extends StatelessWidget {
  final JuiceMatch match;
  final String myUid;

  const _MatchNotificationTile(
      {required this.match, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final partnerUid = match.getPartnerUid(myUid);
    final partnerName = match.getPartnerName(myUid);
    final partnerPhoto = match.getPartnerPhoto(myUid);
    final isUnread = !match.readByUids.contains(myUid);

    // "NEW" if created in last 24h AND not yet read
    final isNew = isUnread &&
        match.createdAt != null &&
        DateTime.now().difference(match.createdAt!).inHours < 24;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey[300],
        backgroundImage: (partnerPhoto != null && partnerPhoto.isNotEmpty)
            ? CachedNetworkImageProvider(partnerPhoto)
            : null,
        child: (partnerPhoto == null || partnerPhoto.isEmpty)
            ? Icon(Icons.person, color: Colors.grey[500])
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              partnerName,
              style: TextStyle(
                fontWeight:
                    isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isNew)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: JuiceTheme.primaryTangerine,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        match.lastMessage.isNotEmpty
            ? match.lastMessage
            : '🎉 You matched! Say hello.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isUnread ? null : Colors.grey[500],
          fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _timeAgo(match.lastMessageTime),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          if (isUnread)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: JuiceTheme.primaryTangerine,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: () async {
        // Mark as read
        if (isUnread) {
          await service.markMatchRead(match.matchId, myUid);
        }
        if (!context.mounted) return;
        // Navigate to the partner's full profile
        final partnerUser =
            await service.getUserOnce(partnerUid);
        if (!context.mounted || partnerUser == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              user: partnerUser,
              sparksScore: match.sparksScore,
            ),
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}
