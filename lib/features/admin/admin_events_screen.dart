import 'package:flutter/material.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';

class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      body: StreamBuilder<List<JuiceEvent>>(
        stream: service.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_note_rounded,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No events yet',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showEventForm(context, service),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create First Event'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JuiceTheme.primaryTangerine,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: JuiceTheme.primaryTangerine
                        .withValues(alpha: 0.1),
                    child: Icon(_categoryIcon(event.category),
                        color: JuiceTheme.primaryTangerine),
                  ),
                  title: Text(event.title,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text('${event.category} · ${event.date}'),
                      Text('${event.attendees} attending · ${event.location}',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _showEventForm(context, service, event: event);
                      } else if (action == 'delete') {
                        _confirmDelete(context, service, event);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_rounded,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventForm(context, service),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Event'),
        backgroundColor: JuiceTheme.primaryTangerine,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showEventForm(BuildContext context, FirestoreService service,
      {JuiceEvent? event}) {
    showDialog(
      context: context,
      builder: (_) => _EventFormDialog(event: event, service: service),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FirestoreService service,
      JuiceEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text('Delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await service.deleteEvent(event.id);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'family':
        return Icons.family_restroom_rounded;
      case 'career':
        return Icons.business_center_rounded;
      case 'lifestyle':
        return Icons.self_improvement_rounded;
      case 'ethics':
        return Icons.balance_rounded;
      case 'fun':
        return Icons.celebration_rounded;
      default:
        return Icons.event_rounded;
    }
  }
}

class _EventFormDialog extends StatefulWidget {
  final JuiceEvent? event;
  final FirestoreService service;

  const _EventFormDialog({this.event, required this.service});

  @override
  State<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<_EventFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;
  String _selectedCategory = 'Lifestyle';
  DateTime? _selectedDate;
  bool _saving = false;

  static const _categories = [
    'Family', 'Career', 'Lifestyle', 'Ethics', 'Fun', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event?.title ?? '');
    _location = TextEditingController(
        text: widget.event?.location ?? 'Kampala, Uganda');
    _description =
        TextEditingController(text: widget.event?.description ?? '');
    _selectedCategory = (widget.event?.category.isNotEmpty == true &&
            _categories.contains(widget.event?.category))
        ? widget.event!.category
        : 'Lifestyle';
    if (widget.event?.date.isNotEmpty == true) {
      try {
        _selectedDate = DateTime.parse(widget.event!.date);
      } catch (_) {
        _selectedDate = null;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String get _formattedDate {
    if (_selectedDate == null) return '';
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[_selectedDate!.month]} ${_selectedDate!.day}, ${_selectedDate!.year}';
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event title is required')));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pick a date')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'title': _title.text.trim(),
        'category': _selectedCategory,
        'date': _selectedDate!.toIso8601String(),
        'location': _location.text.trim(),
        'description': _description.text.trim(),
      };
      if (widget.event != null) {
        await widget.service.updateEvent(widget.event!.id, data);
      } else {
        await widget.service.createEvent(JuiceEvent(
          id: '',
          title: data['title'] as String,
          category: data['category'] as String,
          date: data['date'] as String,
          attendees: 0,
          location: data['location'] as String,
          description: data['description'] as String,
        ));
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event != null ? 'Edit Event' : 'New Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_title, 'Title *'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v ?? _selectedCategory),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(
                  _selectedDate == null ? 'Tap to pick a date' : _formattedDate,
                  style: TextStyle(
                    color: _selectedDate == null ? Colors.grey : null,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _field(_location, 'Location'),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
              backgroundColor: JuiceTheme.primaryTangerine),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(widget.event != null ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {String? hint}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
    );
  }
}
