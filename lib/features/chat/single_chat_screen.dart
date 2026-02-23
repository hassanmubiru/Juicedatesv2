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

  const SingleChatScreen({
    super.key,
    required this.name,
    required this.matchId,
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

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
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
          _service.updateMatchTier(widget.matchId, _currentTier);
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
              MaterialPageRoute(builder: (_) => const VideoCallScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioCallScreen()),
            ),
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

  @override
  State<SingleChatScreen> createState() => _SingleChatScreenState();
}

class _SingleChatScreenState extends State<SingleChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hey! Your profile summary is so cool.', 'isMe': false, 'tier': 1},
    {'text': 'Haha thanks! I really value family time.', 'isMe': true, 'tier': 1},
    {'text': 'Same here! That is why we matched with 92% Sparks.', 'isMe': false, 'tier': 1},
  ];

  int _currentTier = 1;
  double _progression = 0.6; // 60% through Tier 1

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'text': _controller.text,
        'isMe': true,
        'tier': _currentTier,
      });
      _controller.clear();
      _progression += 0.1;
      if (_progression >= 1.0) {
        _progression = 0.1;
        _currentTier = (_currentTier % 4) + 1;
      }
    });
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
                MaterialPageRoute(builder: (_) => const VideoCallScreen()),
              )),
          IconButton(
              icon: const Icon(Icons.call_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AudioCallScreen()),
              )),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: TierMeter(tier: _currentTier, progression: _progression),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: msg['isMe'] ? JuiceTheme.primaryTangerine : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: msg['isMe'] ? const Radius.circular(0) : const Radius.circular(20),
                        bottomLeft: msg['isMe'] ? const Radius.circular(20) : const Radius.circular(0),
                      ),
                    ),
                    child: Text(
                      msg['text'],
                      style: TextStyle(
                        color: msg['isMe'] ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.mic_rounded, color: _currentTier >= 2 ? Colors.orange : Colors.grey),
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
            icon: const Icon(Icons.send_rounded, color: JuiceTheme.primaryTangerine),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
