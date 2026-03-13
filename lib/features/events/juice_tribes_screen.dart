import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import 'event_details_screen.dart';

class JuiceTribesScreen extends StatelessWidget {
  const JuiceTribesScreen({super.key});

  static const _fallbackTribes = [
    {
      'id': 'local_1',
      'title': 'Family First Picnic',
      'category': 'Family',
      'date': 'Oct 24, 2026',
      'attendees': 42,
    },
    {
      'id': 'local_2',
      'title': 'Startup Founders Mixer',
      'category': 'Career',
      'date': 'Oct 26, 2026',
      'attendees': 18,
    },
    {
      'id': 'local_3',
      'title': 'Sunset Yoga & Values',
      'category': 'Lifestyle',
      'date': 'Oct 28, 2026',
      'attendees': 35,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Juice Tribes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEventSheet(context, service),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Event'),
        backgroundColor: JuiceTheme.primaryTangerine,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<JuiceEvent>>(
        stream: service.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data ?? [];
          if (events.isEmpty) return _buildFallbackList(context);
          return _buildEventList(context, events);
        },
      ),
    );
  }

  void _showCreateEventSheet(BuildContext context, FirestoreService service) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: 'Kampala, Uganda');
    String category = 'Lifestyle';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create a Tribe Event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Event title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['Family', 'Career', 'Lifestyle', 'Ethics', 'Fun']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setS(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateCtrl,
                  decoration: InputDecoration(
                    labelText: 'Date (e.g. Apr 20, 2026)',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      dateCtrl.text =
                          '${_monthName(picked.month)} ${picked.day}, ${picked.year}';
                    }
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    prefixIcon: const Icon(Icons.location_on_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JuiceTheme.primaryTangerine,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty ||
                              dateCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Please fill in title and date')));
                            return;
                          }
                          setS(() => saving = true);
                          final uid =
                              FirebaseAuth.instance.currentUser?.uid ?? '';
                          final event = JuiceEvent(
                            id: '',
                            title: titleCtrl.text.trim(),
                            category: category,
                            date: dateCtrl.text,
                            attendees: 1,
                            attendeeUids: [uid],
                            description: descCtrl.text.trim(),
                            location: locationCtrl.text.trim(),
                          );
                          await service.createEvent(event);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Event created!')));
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Event',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  Widget _buildFallbackList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fallbackTribes.length,
      itemBuilder: (context, index) {
        final t = Map<String, dynamic>.from(_fallbackTribes[index]);
        return _buildEventCard(
          context,
          JuiceEvent(
            id: t['id'] as String,
            title: t['title'] as String,
            category: t['category'] as String,
            date: t['date'] as String,
            attendees: t['attendees'] as int,
          ),
        );
      },
    );
  }

  Widget _buildEventList(BuildContext context, List<JuiceEvent> events) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) =>
          _buildEventCard(context, events[index]),
    );
  }

  Widget _buildEventCard(BuildContext context, JuiceEvent event) {
    final iconMap = {
      'Family': Icons.family_restroom_rounded,
      'Career': Icons.business_center_rounded,
      'Lifestyle': Icons.self_improvement_rounded,
      'Ethics': Icons.balance_rounded,
      'Fun': Icons.celebration_rounded,
    };
    final icon = iconMap[event.category] ?? Icons.event_rounded;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EventDetailsScreen(event: event)),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: JuiceTheme.primaryGradient,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child:
                  Icon(icon, size: 60, color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: JuiceTheme.primaryTangerine
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.category,
                          style: const TextStyle(
                              color: JuiceTheme.primaryTangerine,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      Text(event.date,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(event.title,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.people_rounded,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${event.attendees} attending',
                        style:
                            const TextStyle(color: Colors.grey)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
