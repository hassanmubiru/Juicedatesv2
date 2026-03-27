import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import 'single_chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: StreamBuilder<List<JuiceMatch>>(
        stream: service.getMatches(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          
          final allMatches = snapshot.data ?? [];
          if (allMatches.isEmpty) return _buildEmptyState();

          final newMatches = allMatches.where((m) => m.messageCount == 0).toList();
          final activeMatches = allMatches.where((m) => m.messageCount > 0).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // New Matches Section (Horizontal Scroll)
              if (newMatches.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Text(
                      'New Matches',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: JuiceTheme.primaryTangerine,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: newMatches.length,
                      itemBuilder: (context, index) {
                        return _NewMatchCircle(match: newMatches[index], myUid: uid);
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(indent: 16, endIndent: 16, height: 32)),
              ],

              // Active Messages Section
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              if (activeMatches.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No messages yet.\nReach out and squeeze the day!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _MessageTile(match: activeMatches[index], myUid: uid);
                    },
                    childCount: activeMatches.length,
                  ),
                ),
              // Extra space at bottom
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No matches yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Match with someone and start a conversation!', 
            style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red)));
  }
}

class _NewMatchCircle extends StatelessWidget {
  final JuiceMatch match;
  final String myUid;
  const _NewMatchCircle({required this.match, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final photoUrl = match.getPartnerPhoto(myUid);
    final partnerName = match.getPartnerName(myUid);
    final partnerUid = match.getPartnerUid(myUid);

    return GestureDetector(
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
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [JuiceTheme.primaryTangerine, Colors.orangeAccent],
                ),
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    partnerName.split(' ')[0],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                StreamBuilder<JuiceUser>(
                  stream: FirestoreService().getUser(partnerUid),
                  builder: (context, snap) {
                    if (snap.data?.verificationStatus == 'verified') {
                      return const Padding(
                        padding: EdgeInsets.only(left: 2),
                        child: Icon(Icons.verified_rounded, color: Colors.blue, size: 12),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final JuiceMatch match;
  final String myUid;
  const _MessageTile({required this.match, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final partnerUid = match.getPartnerUid(myUid);
    final partnerName = match.getPartnerName(myUid);
    final photoUrl = match.getPartnerPhoto(myUid);
    final hasUnread = match.lastMessage.isNotEmpty && !match.readByUids.contains(myUid);
    final lastSentByMe = match.lastMessage.isNotEmpty && !hasUnread;

    return ListTile(
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
      leading: StreamBuilder<JuiceUser>(
        stream: service.getUser(partnerUid),
        builder: (context, snap) {
          final isOnline = snap.data?.isOnline ?? false;
          return Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey[200],
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      title: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    partnerName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: hasUnread ? FontWeight.w900 : FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                StreamBuilder<JuiceUser>(
                  stream: service.getUser(partnerUid),
                  builder: (context, snap) {
                    if (snap.data?.verificationStatus == 'verified') {
                      return const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified_rounded, color: Colors.blue, size: 16),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          Text(
            _timeAgo(match.lastMessageTime),
            style: TextStyle(
              fontSize: 11,
              color: hasUnread ? JuiceTheme.primaryTangerine : Colors.grey,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          children: [
            if (lastSentByMe) ...[
              const Icon(Icons.done_all_rounded, size: 14, color: JuiceTheme.primaryTangerine),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                match.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasUnread ? Colors.black87 : Colors.grey,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (hasUnread)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: JuiceTheme.primaryTangerine,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
