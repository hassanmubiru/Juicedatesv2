import 'dart:convert';
import 'package:http/http.dart' as http;

/// Calls the JuiceDates notify server (Express on Render.com) to send
/// FCM push notifications without requiring Firebase Cloud Functions / Blaze plan.
///
/// After deploying to Render, update [_serverUrl] to your Render service URL
/// and [_apiKey] to match the NOTIFY_API_KEY environment variable you set.
class NotifyService {
  NotifyService._();
  static final NotifyService instance = NotifyService._();

  // ── Configuration ─────────────────────────────────────────────────────────
  // Replace these after deploying server to Render.com
  static const String _serverUrl = 'https://juicedates-notify.onrender.com';
  static const String _apiKey    = 'REPLACE_WITH_YOUR_NOTIFY_API_KEY';

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> notifyMatch({
    required String uid1,
    required String uid2,
    required String name1,
    required String name2,
    required String matchId,
    required double sparksScore,
  }) async {
    await _post('/api/notify/match', {
      'uid1': uid1,
      'uid2': uid2,
      'name1': name1,
      'name2': name2,
      'matchId': matchId,
      'sparksScore': sparksScore,
    });
  }

  Future<void> notifyMessage({
    required String senderUid,
    required String senderName,
    required String recipientUid,
    required String matchId,
    required String text,
  }) async {
    await _post('/api/notify/message', {
      'senderUid': senderUid,
      'senderName': senderName,
      'recipientUid': recipientUid,
      'matchId': matchId,
      'text': text,
    });
  }

  Future<void> notifyAnnouncement({
    required String title,
    required String body,
  }) async {
    await _post('/api/notify/announcement', {
      'title': title,
      'body': body,
    });
  }

  Future<void> notifyBan({
    required String uid,
    required String displayName,
  }) async {
    await _post('/api/notify/ban', {
      'uid': uid,
      'displayName': displayName,
    });
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _post(String path, Map<String, dynamic> body) async {
    if (_apiKey == 'REPLACE_WITH_YOUR_NOTIFY_API_KEY') return; // not configured yet
    try {
      await http.post(
        Uri.parse('$_serverUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Notifications are best-effort — never break the main flow
    }
  }
}
