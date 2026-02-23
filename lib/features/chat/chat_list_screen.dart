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

              return ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SingleChatScreen(
                      name: partnerName,
                      matchId: match.matchId,
                    ),
                  ),
                ),
                leading: Stack(
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
                ),
                title: Row(
                  children: [
                    Text(partnerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _buildTierBadge(match.tier),
                  ],
                ),
                subtitle: Text(
                  match.lastMessage.isEmpty
                      ? 'Start a conversation!'
                      : match.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _timeAgo(match.lastMessageTime),
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
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
    {
      'name': 'Sarah',
      'lastMsg': 'That sounds like a great plan!',
      'time': '10:30 AM',
      'unread': 2,
      'tier': 2
    },
    {
      'name': 'James',
      'lastMsg': 'Loved your voice note!',
      'time': '9:15 AM',
      'unread': 0,
      'tier': 1
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: _chats.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _chats.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SingleChatScreen(name: chat['name'])),
              );
            },
            leading: Stack(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: JuiceTheme.secondaryCitrus,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: JuiceTheme.juiceGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Text(chat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _buildTierBadge(chat['tier']),
              ],
            ),
            subtitle: Text(
              chat['lastMsg'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(chat['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (chat['unread'] > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: JuiceTheme.primaryTangerine,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${chat['unread']}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTierBadge(int tier) {
    String label;
    switch (tier) {
      case 1:
        label = '💚';
        break;
      case 2:
        label = '🧡';
        break;
      case 3:
        label = '❤️';
        break;
      case 4:
        label = '💎';
        break;
      default:
        label = '💚';
    }
    return Text(label, style: const TextStyle(fontSize: 12));
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No chats yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Match with someone and start a conversation!',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
