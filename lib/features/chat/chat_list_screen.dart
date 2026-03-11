import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      appBar: AppBar(title: const Text('Chats')),
      body: StreamBuilder<List<JuiceMatch>>(
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
                    const Text('Could not load chats',
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
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final match = matches[index];
              final partnerName = match.getPartnerName(uid);
              final photoUrl = match.getPartnerPhoto(uid);
              final partnerUid = match.getPartnerUid(uid);
              // "NEW" = last message was from partner and I haven't read it
              final hasUnread = match.lastMessage.isNotEmpty &&
                  !match.readByUids.contains(uid);
              // Last message was sent by me → show read receipt
              final lastSentByMe = match.lastMessage.isNotEmpty &&
                  !hasUnread;

              return Container(
                decoration: hasUnread
                    ? BoxDecoration(
                        color: JuiceTheme.primaryTangerine.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
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
                  leading: StreamBuilder<JuiceUser>(
                stream: service.getUser(partnerUid ?? ''),
                builder: (context, userSnap) {
                  final isOnline = userSnap.data?.isOnline ?? false;
                  return Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: JuiceTheme.secondaryCitrus,
                        backgroundImage:
                            photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? const Icon(Icons.person,
                                color: Colors.white, size: 30)
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
                              color: JuiceTheme.juiceGreen,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
                  title: Row(
                    children: [
                      Text(partnerName,
                          style: TextStyle(
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.bold)),
                      const SizedBox(width: 8),
                      _buildTierBadge(match.tier),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      // Read receipt tick for my last sent message
                      if (lastSentByMe) ...[
                        const Icon(Icons.done_all_rounded,
                            size: 14,
                            color: JuiceTheme.primaryTangerine),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          match.lastMessage.isEmpty
                              ? 'Start a conversation!'
                              : match.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: hasUnread ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _timeAgo(match.lastMessageTime),
                        style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? JuiceTheme.primaryTangerine
                                : Colors.grey),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: JuiceTheme.primaryTangerine,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('NEW',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildTierBadge(int tier) {
    const labels = {1: '💚', 2: '🧡', 3: '❤️', 4: '💎'};
    return Text(labels[tier] ?? '💚',
        style: const TextStyle(fontSize: 12));
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No chats yet',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Match with someone and start a conversation!',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

