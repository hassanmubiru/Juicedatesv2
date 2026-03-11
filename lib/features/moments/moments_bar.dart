import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/cloudinary_service.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';

/// Horizontal story-ring bar shown at the top of the Feed.
/// Inspired by hookup4u's "Moments" feature — 24-hour posts visible to all.
class MomentsBar extends StatefulWidget {
  const MomentsBar({super.key});

  @override
  State<MomentsBar> createState() => _MomentsBarState();
}

class _MomentsBarState extends State<MomentsBar> {
  final _service = FirestoreService();
  String? _myUid;
  JuiceUser? _myUser;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    if (_myUid == null) return;
    final u = await _service.getUserOnce(_myUid!);
    if (mounted) setState(() => _myUser = u);
  }

  void _showPostSheet() {
    if (_myUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PostMomentSheet(service: _service, user: _myUser!),
    );
  }

  void _openViewer(List<JuiceMoment> moments, int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              MomentViewer(moments: moments, startIndex: startIndex)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_myUid == null) return const SizedBox.shrink();

    return StreamBuilder<List<JuiceMoment>>(
      stream: _service.getActiveMoments(_myUid!),
      builder: (context, snap) {
        final moments = snap.data ?? [];
        final myMoments =
            moments.where((m) => m.uid == _myUid).toList();
        final otherMoments =
            moments.where((m) => m.uid != _myUid).toList();

        // Group others by uid → one ring per person
        final Map<String, List<JuiceMoment>> byUser = {};
        for (final m in otherMoments) {
          byUser.putIfAbsent(m.uid, () => []).add(m);
        }

        return SizedBox(
          height: 86,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            children: [
              // ── My Story ring ────────────────────────────────────────
              _StoryRing(
                label: 'My Story',
                photoUrl: _myUser?.photoUrl,
                hasStory: myMoments.isNotEmpty,
                isOwn: true,
                onTap: () => myMoments.isEmpty
                    ? _showPostSheet()
                    : _openViewer(myMoments, 0),
              ),
              // ── Other users ──────────────────────────────────────────
              ...byUser.entries.map((entry) {
                final userMoments = entry.value;
                final first = userMoments.first;
                return _StoryRing(
                  label: first.displayName,
                  photoUrl: first.authorPhotoUrl,
                  hasStory: true,
                  isOwn: false,
                  onTap: () => _openViewer(userMoments, 0),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ── Story ring ──────────────────────────────────────────────────────────────

class _StoryRing extends StatelessWidget {
  final String label;
  final String? photoUrl;
  final bool hasStory;
  final bool isOwn;
  final VoidCallback onTap;

  const _StoryRing({
    required this.label,
    this.photoUrl,
    required this.hasStory,
    required this.isOwn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory ? JuiceTheme.primaryGradient : null,
                    color: hasStory ? null : Colors.white24,
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.white10,
                    backgroundImage:
                        photoUrl != null && photoUrl!.isNotEmpty
                            ? NetworkImage(photoUrl!)
                            : null,
                    child: photoUrl == null || photoUrl!.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white70, size: 24)
                        : null,
                  ),
                ),
                if (isOwn && !hasStory)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: JuiceTheme.primaryTangerine,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.add,
                        color: Colors.white, size: 12),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label.length > 7 ? '${label.substring(0, 6)}…' : label,
              style: const TextStyle(
                  fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full-screen moment viewer ────────────────────────────────────────────────

class MomentViewer extends StatefulWidget {
  final List<JuiceMoment> moments;
  final int startIndex;

  const MomentViewer(
      {super.key, required this.moments, required this.startIndex});

  @override
  State<MomentViewer> createState() => _MomentViewerState();
}

class _MomentViewerState extends State<MomentViewer>
    with SingleTickerProviderStateMixin {
  late int _index;
  late AnimationController _ctrl;
  final _replyCtrl = TextEditingController();
  bool _replyFocused = false;
  bool _sendingReply = false;
  final _service = FirestoreService();

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;
  String get _myName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Someone';

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _advance();
      })
      ..forward();
  }

  void _advance() {
    if (_index < widget.moments.length - 1) {
      setState(() => _index++);
      _ctrl.forward(from: 0);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _myUid == null) return;
    setState(() => _sendingReply = true);
    try {
      await _service.replyToMoment(
        momentId: widget.moments[_index].id,
        replierUid: _myUid!,
        replierName: _myName,
        text: text,
      );
      _replyCtrl.clear();
      if (mounted) {
        setState(() => _replyFocused = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply sent! 💬')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _advance,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            moment.imageUrl != null
                ? Image.network(moment.imageUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                            gradient: JuiceTheme.primaryGradient)))
                : Container(
                    decoration:
                        BoxDecoration(gradient: JuiceTheme.primaryGradient)),

            // Dark overlay
            Container(color: Colors.black38),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress segments
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: List.generate(widget.moments.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: LinearProgressIndicator(
                              value: i < _index
                                  ? 1.0
                                  : i == _index
                                      ? _ctrl.value
                                      : 0.0,
                              backgroundColor: Colors.white30,
                              valueColor: const AlwaysStoppedAnimation(
                                  Colors.white),
                              minHeight: 3,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Author row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage: moment.authorPhotoUrl != null &&
                                  moment.authorPhotoUrl!.isNotEmpty
                              ? NetworkImage(moment.authorPhotoUrl!)
                              : null,
                          child: moment.authorPhotoUrl == null
                              ? const Icon(Icons.person,
                                  color: Colors.white70)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(moment.displayName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text(_timeAgo(moment.createdAt),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Moment text — bottom
            Positioned(
              bottom: 60,
              left: 24,
              right: 24,
              child: Text(
                moment.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Post moment bottom sheet ────────────────────────────────────────────────

class _PostMomentSheet extends StatefulWidget {
  final FirestoreService service;
  final JuiceUser user;
  const _PostMomentSheet({required this.service, required this.user});

  @override
  State<_PostMomentSheet> createState() => _PostMomentSheetState();
}

class _PostMomentSheetState extends State<_PostMomentSheet> {
  final _ctrl = TextEditingController();
  bool _posting = false;
  String? _emoji;

  static const _quickEmojis = [
    '🌟', '❤️', '🔥', '✨', '🍊', '😊', '💬', '🎉', '💪', '🌈'
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final body =
        ((_emoji != null ? '$_emoji ' : '') + _ctrl.text).trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    await widget.service.postMoment(
        widget.user.uid, widget.user.displayName, widget.user.photoUrl, body);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Post a Moment 🌟',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const Text('Visible to everyone for 24 hours',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            // Emoji quick-picks
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickEmojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final e = _quickEmojis[i];
                  final selected = _emoji == e;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _emoji = selected ? null : e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? JuiceTheme.primaryTangerine.withValues(alpha: 0.15)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                            ? Border.all(
                                color: JuiceTheme.primaryTangerine)
                            : null,
                      ),
                      child: Center(
                          child:
                              Text(e, style: const TextStyle(fontSize: 22))),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLength: 150,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: JuiceTheme.primaryTangerine,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _posting ? null : _post,
                child: _posting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Share Moment',
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
