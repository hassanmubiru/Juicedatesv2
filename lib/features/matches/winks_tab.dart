import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../home/user_profile_screen.dart';

/// Shows who sent a wink to the current user.
/// Inspired by hookup4u's wink/flirt feature — a lightweight pre-like signal.
class WinksTab extends StatefulWidget {
  const WinksTab({super.key});

  @override
  State<WinksTab> createState() => _WinksTabState();
}

class _WinksTabState extends State<WinksTab> {
  final _service = FirestoreService();
  String? _uid;
  JuiceUser? _myUser;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid == null) return;
    final u = await _service.getUserOnce(_uid!);
    if (mounted) setState(() => _myUser = u);
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<JuiceWink>>(
      stream: _service.getWinksReceived(_uid!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final winks = snap.data ?? [];
        if (winks.isEmpty) return _buildEmpty();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: winks.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) => _WinkTile(
            wink: winks[i],
            myUser: _myUser,
            service: _service,
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
          Text('👋', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('No winks yet',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'When someone winks at you from the feed,\nthey\'ll appear here.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WinkTile extends StatefulWidget {
  final JuiceWink wink;
  final JuiceUser? myUser;
  final FirestoreService service;

  const _WinkTile(
      {required this.wink,
      required this.myUser,
      required this.service});

  @override
  State<_WinkTile> createState() => _WinkTileState();
}

class _WinkTileState extends State<_WinkTile> {
  bool _acted = false;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _likeBack() async {
    if (widget.myUser == null) return;
    final winker = await widget.service.getUserOnce(widget.wink.fromUid);
    if (winker == null || !mounted) return;
    try {
      final match = await widget.service.likeUser(widget.myUser!, winker);
      if (!mounted) return;
      setState(() => _acted = true);
      if (match != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("It's a match with ${winker.displayName}! 🎉"),
              backgroundColor: JuiceTheme.primaryTangerine),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Liked ${winker.displayName} back! 💛')),
        );
      }
    } on DailyLimitException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Daily like limit reached — upgrade to Plus+')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wink = widget.wink;
    return ListTile(
      leading: GestureDetector(
        onTap: () async {
          final u = await widget.service.getUserOnce(wink.fromUid);
          if (u == null || !context.mounted) return;
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)));
        },
        child: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: JuiceTheme.primaryTangerine,
              backgroundImage:
                  wink.fromPhoto != null && wink.fromPhoto!.isNotEmpty
                      ? NetworkImage(wink.fromPhoto!)
                      : null,
              child: wink.fromPhoto == null || wink.fromPhoto!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            // Unread dot
            if (!wink.seen)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                      color: JuiceTheme.primaryTangerine,
                      shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
      title: Text(wink.fromName,
          style: TextStyle(
              fontWeight:
                  wink.seen ? FontWeight.normal : FontWeight.bold)),
      subtitle: Text(
        '👋 Winked at you  •  ${_timeAgo(wink.createdAt)}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: _acted
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Liked ✓',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JuiceTheme.primaryTangerine,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: _likeBack,
              child: const Text('Like Back ❤️',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
      onTap: () {
        if (!wink.seen) widget.service.markWinkSeen(wink.id);
      },
    );
  }
}
