import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_button.dart';

class EventDetailsScreen extends StatefulWidget {
  final JuiceEvent event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _service = FirestoreService();
  late bool _hasRsvped;
  late int _attendees;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _hasRsvped = widget.event.attendeeUids.contains(uid);
    _attendees = widget.event.attendees;
  }

  Future<void> _toggleRsvp() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      if (_hasRsvped) {
        await _service.cancelRsvp(widget.event.id, uid);
        setState(() {
          _hasRsvped = false;
          _attendees--;
        });
      } else {
        await _service.rsvpEvent(widget.event.id, uid);
        setState(() {
          _hasRsvped = true;
          _attendees++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconMap = {
      'Family': Icons.family_restroom_rounded,
      'Career': Icons.business_center_rounded,
      'Lifestyle': Icons.self_improvement_rounded,
      'Ethics': Icons.balance_rounded,
      'Fun': Icons.celebration_rounded,
    };
    final icon =
        iconMap[widget.event.category] ?? Icons.event_rounded;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.event.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration:
                    BoxDecoration(gradient: JuiceTheme.primaryGradient),
                child: Icon(icon,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildInfoChip(
                          Icons.calendar_today_rounded,
                          widget.event.date),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                          Icons.people_rounded, '$_attendees Joined'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('About this Event',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.description.isNotEmpty
                        ? widget.event.description
                        : 'Join your fellow JuiceDates members who share '
                            'similar values! This event is designed to foster '
                            'deep connections and meaningful conversations in '
                            'a relaxed environment.',
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text('Location',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map_rounded,
                              size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(widget.event.location,
                              style: const TextStyle(
                                  color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _loading
                      ? const Center(
                          child: CircularProgressIndicator())
                      : JuiceButton(
                          onPressed: _toggleRsvp,
                          text: _hasRsvped
                              ? 'Cancel RSVP'
                              : 'RSVP Now',
                          isGradient: !_hasRsvped,
                        ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: JuiceTheme.primaryTangerine.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: JuiceTheme.primaryTangerine),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(tribe['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
                child: Icon(tribe['image'] as IconData, size: 80, color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildInfoChip(Icons.calendar_today_rounded, tribe['date']),
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.people_rounded, '${tribe['attendees']} Joined'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('About this Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Join your fellow JuiceDates members who share similar values! This event is designed to foster deep connections and meaningful conversations in a relaxed environment.',
                    style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text('Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_rounded, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Map Preview (Kampala Central)', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  JuiceButton(
                    onPressed: () {},
                    text: 'RSVP Now',
                    isGradient: true,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: JuiceTheme.primaryTangerine.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: JuiceTheme.primaryTangerine),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
