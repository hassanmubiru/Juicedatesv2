import 'package:flutter/material.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _service = FirestoreService();
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _filter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _filter = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
            onChanged: (v) => setState(() => _filter = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<JuiceUser>>(
            stream: _service.getAllUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data ?? [];
              final users = _filter.isEmpty
                  ? all
                  : all
                      .where((u) =>
                          u.displayName.toLowerCase().contains(_filter) ||
                          (u.email?.toLowerCase().contains(_filter) ?? false) ||
                          u.city.toLowerCase().contains(_filter))
                      .toList();

              if (users.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              return LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                if (isWide) {
                  return _UsersDataTable(
                    users: users,
                    onAction: _handleAction,
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _UserListTile(
                        user: user, onAction: _handleAction);
                  },
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(String action, JuiceUser user) async {
    switch (action) {
      case 'view':
        showDialog(
            context: context,
            builder: (_) => _UserDetailDialog(user: user));
        break;
      case 'ban':
        await _service.banUser(user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${user.displayName} banned')));
        }
        break;
      case 'unban':
        await _service.unbanUser(user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${user.displayName} unbanned')));
        }
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Account?'),
            content: Text(
                'Permanently delete ${user.displayName}\'s account? This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await _service.deleteUserAccount(user.uid);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${user.displayName} deleted')));
          }
        }
        break;
    }
  }
}

class _Badge extends StatelessWidget {  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuItem(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: color)),
    ]);
  }
}

class _UserDetailDialog extends StatelessWidget {
  final JuiceUser user;
  const _UserDetailDialog({required this.user});

  @override
  Widget build(BuildContext context) {
    final p = user.juiceProfile;
    return AlertDialog(
      title: Text(user.displayName),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user.photoUrl != null && user.photoUrl!.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.network(user.photoUrl!,
                      width: 80, height: 80, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 12),
            _Row('UID', user.uid),
            _Row('Email', user.email ?? '—'),
            _Row('City', user.city),
            _Row('Age', '${user.age}'),
            _Row('Bio', user.bio ?? '—'),
            _Row('Summary', user.juiceSummary),
            _Row('Premium', user.isPremium ? 'Yes' : 'No'),
            _Row('Photos', '${user.photos.length}'),
            _Row('Banned', user.isBanned ? 'Yes' : 'No'),
            const Divider(height: 20),
            const Text('Juice Profile',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _ProfileBar('Family', p.family),
            _ProfileBar('Career', p.career),
            _ProfileBar('Lifestyle', p.lifestyle),
            _ProfileBar('Ethics', p.ethics),
            _ProfileBar('Fun', p.fun),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }

  Widget _Row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 68,
              child: Text('$label:',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12))),
          Expanded(
              child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _ProfileBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(
                  JuiceTheme.primaryTangerine),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(value * 100).round()}%',
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
