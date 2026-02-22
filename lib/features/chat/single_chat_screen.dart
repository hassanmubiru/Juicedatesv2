import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';
import '../../widgets/tier_meter.dart';
import '../calling/video_call_screen.dart';
import '../calling/audio_call_screen.dart';

class SingleChatScreen extends StatefulWidget {
  final String name;
  const SingleChatScreen({super.key, required this.name});

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
