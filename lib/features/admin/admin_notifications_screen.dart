import 'package:flutter/material.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends State<AdminNotificationsScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _service = FirestoreService();
  bool _sending = false;
  final List<Map<String, String>> _history = [];

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and body are required')));
      return;
    }
    setState(() => _sending = true);
    try {
      await _service.sendAnnouncement(
          _titleCtrl.text.trim(), _bodyCtrl.text.trim());
      _history.insert(0, {
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'time': 'just now',
      });
      _titleCtrl.clear();
      _bodyCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Announcement saved! FCM will broadcast it.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.campaign_rounded,
              size: 56, color: JuiceTheme.primaryTangerine),
          const SizedBox(height: 12),
          const Text(
            'Broadcast Notification',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Saved to Firestore — a Cloud Function delivers via FCM',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Notification Title',
              prefixIcon: const Icon(Icons.title_rounded),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Message Body',
              prefixIcon: const Icon(Icons.message_rounded),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'Sending...' : 'Send to All Users'),
            style: FilledButton.styleFrom(
              backgroundColor: JuiceTheme.primaryTangerine,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text('Sent This Session',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ..._history.map((n) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.notifications_rounded,
                        color: JuiceTheme.primaryTangerine),
                    title: Text(n['title']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(n['body']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: Text(n['time']!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
                )),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
