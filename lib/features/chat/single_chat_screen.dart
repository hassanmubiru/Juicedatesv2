import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../../core/utils/juice_engine.dart';
import '../calling/video_call_screen.dart';
import '../calling/audio_call_screen.dart';
import '../../widgets/tier_meter.dart';

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
  final FocusNode _textFocusNode = FocusNode();
  final _service = FirestoreService();
  late final String _myUid;
  String _myName = '';
  int _currentTier = 1;
  double _progression = 0.0;
  int _messageCount = 0;
  String? _partnerPhotoUrl;
  JuiceUser? _partnerUser;
  JuiceUser? _myUser;
  bool _showEmojiPanel = false;
  int _emojiCategoryIndex = 0;

  // Emoji categories shown in the picker
  static const _emojiCategories = [
    (
      '😊',
      [
        '😀', '😂', '🤣', '😊', '😍', '🥰', '😘', '😜', '😎', '🤩',
        '😢', '😭', '😡', '🥺', '🤔', '😴', '🤗', '😏', '🙄', '😬',
        '🥳', '🤭', '😇', '🫠', '😤', '🤤', '🥵', '🤯', '😱', '🫣',
      ]
    ),
    (
      '❤️',
      [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💖', '💗',
        '💓', '💞', '💕', '💟', '❣️', '💔', '🔥', '✨', '💫', '⭐',
        '🌟', '💯', '🎉', '🎊', '🥂', '🍾', '🎁', '🌹', '💐', '🌺',
      ]
    ),
    (
      '👋',
      [
        '👋', '🤝', '👍', '👎', '👏', '🙌', '🤜', '🤛', '✌️', '🤞',
        '🤟', '🤙', '👈', '👉', '👆', '👇', '☝️', '💪', '🦾', '🙏',
        '💅', '🤳', '✍️', '🫶', '🫂', '🫰', '🤌', '👀', '👅', '💋',
      ]
    ),
    (
      '🍕',
      [
        '🍕', '🍔', '🌮', '🍜', '🍣', '🍩', '🍫', '🍦', '🥤', '🍺',
        '🍷', '🥗', '🍉', '🍓', '🍑', '🍒', '🍋', '🍊', '🥭', '🍍',
        '🌽', '🍁', '🌸', '🌴', '🦋', '🐶', '🐱', '🦊', '🐼', '🦁',
      ]
    ),
    (
      '🚗',
      [
        '🚗', '✈️', '🚀', '⛵', '🏖️', '🏔️', '🌍', '🗺️', '🎡', '🎢',
        '🎠', '🏋️', '⚽', '🏀', '🎾', '🏄', '🎯', '🎮', '🎲', '🃏',
        '🎭', '🎵', '🎸', '🎤', '📸', '💻', '📱', '⌚', '🔑', '💎',
      ]
    ),
  ];

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadMatchState();
    // When the keyboard appears, close the emoji panel
    _textFocusNode.addListener(() {
      if (_textFocusNode.hasFocus && _showEmojiPanel) {
        setState(() => _showEmojiPanel = false);
      }
    });
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
        _myName = match.userNames[_myUid] ?? '';
      });
    }
    // Mark all incoming messages as read
    _service.markMessagesRead(widget.matchId, _myUid);
    // Load user profiles for icebreaker suggestion generation
    if (widget.partnerUid != null) {
      final partner = await _service.getUserOnce(widget.partnerUid!);
      final me = await _service.getUserOnce(_myUid);
      if (mounted) setState(() { _partnerUser = partner; _myUser = me; });
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

  void _insertEmoji(String emoji) {
    final sel = _controller.selection;
    final text = _controller.text;
    final cursor = sel.isValid ? sel.baseOffset : text.length;
    final newText =
        text.substring(0, cursor) + emoji + text.substring(cursor);
    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + emoji.length),
    );
  }

  void _sendGift(String emoji) {
    _service.sendMessage(
      widget.matchId,
      JuiceMessage(
        senderId: _myUid,
        text: '$emoji gift',
        tierUnlocked: _currentTier,
        timestamp: DateTime.now(),
        type: 'gift',
        giftEmoji: emoji,
      ),
      recipientUid: widget.partnerUid,
      senderName: _myName.isNotEmpty ? _myName : 'Your match',
    );
  }

  void _showGiftPicker() {
    const gifts = ['🌹', '💝', '🍊', '⭐', '🎉', '💐', '🍫', '🎵'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send a Virtual Gift',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: gifts
                  .map((g) => GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _sendGift(g);
                        },
                        child: Text(g,
                            style: const TextStyle(fontSize: 40)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
        type: 'text',
      ),
      recipientUid: widget.partnerUid,
      senderName: _myName.isNotEmpty ? _myName : 'Your match',
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

  /// Builds icebreaker question chips when a chat has no messages yet.
  Widget _buildIcebreakers() {
    List<String> questions;
    if (_myUser != null && _partnerUser != null) {
      questions = JuiceEngine.generateIcebreakers(
          _myUser!.juiceProfile, _partnerUser!.juiceProfile);
    } else {
      questions = [
        "What does your ideal weekend look like?",
        "What's something you're passionate about right now?",
        "If you could live anywhere, where would it be?",
      ];
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: JuiceTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Text('\u2728', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 20),
            Text(
              "It's a Juice Match! \ud83c\udf89",
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Break the ice with ${widget.name}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Text(
              'Try asking:',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ...questions.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _controller.text = q,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Text('\ud83d\udca1',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              backgroundImage: (_partnerPhotoUrl != null &&
                      _partnerPhotoUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(_partnerPhotoUrl!)
                  : null,
              child: (_partnerPhotoUrl == null || _partnerPhotoUrl!.isEmpty)
                  ? Icon(Icons.person, color: Colors.grey[500], size: 20)
                  : null,
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

                if (messages.isEmpty) {
                  return _buildIcebreakers();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _myUid;
                    // Gift message — large centered emoji bubble
                    if (msg.type == 'gift' && msg.giftEmoji != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(msg.giftEmoji!,
                                style: const TextStyle(fontSize: 52)),
                            const SizedBox(height: 2),
                            Text(
                              isMe
                                  ? 'You sent a gift 🎁'
                                  : '${widget.name} sent you a gift 🎁',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
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
                              ? const Color(0xFF1C1C1E)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(18).copyWith(
                            bottomRight: isMe
                                ? const Radius.circular(4)
                                : const Radius.circular(18),
                            bottomLeft: isMe
                                ? const Radius.circular(18)
                                : const Radius.circular(4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    msg.readBy.contains(widget.partnerUid)
                                        ? Icons.done_all_rounded
                                        : Icons.done_rounded,
                                    size: 14,
                                    color: msg.readBy.contains(widget.partnerUid)
                                        ? JuiceTheme.primaryTangerine
                                        : Colors.white38,
                                  ),
                                ],
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
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      children: [
        // ── Emoji panel ─────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _showEmojiPanel ? _buildEmojiPanel() : const SizedBox.shrink(),
        ),
        // ── Input row ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            children: [
              // Emoji toggle
              IconButton(
                icon: Icon(
                  _showEmojiPanel
                      ? Icons.keyboard_rounded
                      : Icons.emoji_emotions_outlined,
                  color: Colors.grey[500],
                ),
                onPressed: () {
                  if (!_showEmojiPanel) {
                    FocusScope.of(context).unfocus();
                  } else {
                    _textFocusNode.requestFocus();
                  }
                  setState(() => _showEmojiPanel = !_showEmojiPanel);
                },
              ),
              // Gift
              IconButton(
                icon: Icon(Icons.card_giftcard_outlined, color: Colors.grey[500]),
                onPressed: _showGiftPicker,
                tooltip: 'Send a gift',
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _textFocusNode,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
        ),
      ],
    );
  }

  Widget _buildEmojiPanel() {
    final cats = _emojiCategories;
    final emojis = cats[_emojiCategoryIndex].$2;
    return Container(
      height: 260,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Category tab strip
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: cats.length,
              itemBuilder: (_, i) {
                final selected = i == _emojiCategoryIndex;
                return GestureDetector(
                  onTap: () => setState(() => _emojiCategoryIndex = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.grey[200]
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(cats[i].$1,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              },
            ),
          ),
          // Emoji grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: emojis.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _insertEmoji(emojis[i]),
                child: Center(
                  child:
                      Text(emojis[i], style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
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
      title: Text('Report ${widget.name}'),
      content: RadioGroup<String>(
        groupValue: _selected,
        onChanged: (v) => setState(() => _selected = v),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _reasons
              .map((r) => RadioListTile<String>(
                    value: r,
                    dense: true,
                    title: Text(r),
                  ))
              .toList(),
        ),
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
