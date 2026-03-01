import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../../widgets/tier_meter.dart';
import '../calling/video_call_screen.dart';
import '../calling/audio_call_screen.dart';

class SingleChatScreen extends StatefulWidget {
  final String name;
  final String matchId;
  final String? partnerUid;

  const SingleChatScreen({
    super.key,
    required this.name,
    required this.matchId,
    this.partnerUid,
  });

  @override
  State<SingleChatScreen> createState() => _SingleChatScreenState();
}

class _SingleChatScreenState extends State<SingleChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _service = FirestoreService();
  late final String _myUid;
  int _currentTier = 1;
  double _progression = 0.0;
  int _messageCount = 0;
  String? _partnerPhotoUrl;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadMatchState();
  }

  /// Load persisted tier + message count so chat state survives reopens.
  Future<void> _loadMatchState() async {
    final match = await _service.getMatchOnce(widget.matchId);
    if (match != null && mounted) {
      setState(() {
        _currentTier = match.tier;
        _messageCount = match.messageCount;
        _progression = (_messageCount % 10) / 10.0;
        _partnerPhotoUrl = match.getPartnerPhoto(_myUid);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleMenuAction(String action) async {
    if (widget.partnerUid == null) return;
    if (action == 'report') {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => _ReportDialog(name: widget.name),
      );
      if (reason != null && reason.isNotEmpty) {
        await _service.reportUser(_myUid, widget.partnerUid!, reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted. Thank you.')),
          );
        }
      }
    } else if (action == 'block') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Block ${widget.name}?'),
          content: const Text('They will no longer be able to message you or appear in your feed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Block', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _service.blockUser(_myUid, widget.partnerUid!);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.name} has been blocked.')),
          );
        }
      }
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    _service.sendMessage(
      widget.matchId,
      JuiceMessage(
        senderId: _myUid,
        text: text,
        tierUnlocked: _currentTier,
        timestamp: DateTime.now(),
      ),
    );

    setState(() {
      _messageCount++;
      _progression = (_messageCount % 10) / 10.0;
      if (_messageCount > 0 && _messageCount % 10 == 0) {
        final newTier = (_currentTier % 4) + 1;
        if (newTier > _currentTier) {
          _currentTier = newTier;
          // Persist only the tier change (messageCount is incremented in sendMessage)
          _service.updateMatchTier(widget.matchId, _currentTier, _messageCount);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: JuiceTheme.primaryTangerine,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(widget.name, style: const TextStyle(fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                        name: widget.name,
                        photoUrl: _partnerPhotoUrl,
                      )),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AudioCallScreen(
                        name: widget.name,
                        photoUrl: _partnerPhotoUrl,
                      )),
            ),
          ),
          if (widget.partnerUid != null)
            PopupMenuButton<String>(
              onSelected: (val) => _handleMenuAction(val),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Report User')),
                PopupMenuItem(
                  value: 'block',
                  child: Text('Block User', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: TierMeter(tier: _currentTier, progression: _progression),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<JuiceMessage>>(
              stream: _service.getMessages(widget.matchId),
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
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text('${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }
                final messages = snapshot.data ?? [];
                if (messages.isNotEmpty) _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _myUid;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? JuiceTheme.primaryTangerine
                              : Colors.grey[200],
                          borderRadius:
                              BorderRadius.circular(20).copyWith(
                            bottomRight: isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(20),
                            bottomLeft: isMe
                                ? const Radius.circular(20)
                                : const Radius.circular(0),
                          ),
                        ),
                        child: Text(
                          msg.text,
                          style: TextStyle(
                            color:
                                isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.mic_rounded,
                color: _currentTier >= 2
                    ? Colors.orange
                    : Colors.grey),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded,
                color: JuiceTheme.primaryTangerine),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  final String name;
  const _ReportDialog({required this.name});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selected;
  static const _reasons = [
    'Inappropriate content',
    'Fake profile',
    'Harassment',
    'Spam',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report \${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [RadioGroup<String>(
          groupValue: _selected,
          onChanged: (v) => setState(() => _selected = v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _reasons
                .map((r) => RadioListTile<String>(
                      value: r,
                      title: Text(r),
                    ))
                .toList(),
          ),
        )],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
