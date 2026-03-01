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
        await _service.banUser(user.uid, user.displayName);
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

// ── Mobile list tile ──────────────────────────────────────────────────────
class _UserListTile extends StatelessWidget {
  final JuiceUser user;
  final Future<void> Function(String, JuiceUser) onAction;
  const _UserListTile({required this.user, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: user.isBanned
            ? Colors.red[100]
            : JuiceTheme.primaryTangerine.withValues(alpha: 0.15),
        backgroundImage:
            user.photoUrl != null && user.photoUrl!.isNotEmpty
                ? NetworkImage(user.photoUrl!)
                : null,
        child: user.photoUrl == null || user.photoUrl!.isEmpty
            ? Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: user.isBanned
                        ? Colors.red
                        : JuiceTheme.primaryTangerine),
              )
            : null,
      ),
      title: Row(children: [
        Flexible(
          child: Text(user.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
        if (user.isAdmin) ...[const SizedBox(width: 6), _Badge('Admin', Colors.purple)],
        if (user.isPremium) ...[const SizedBox(width: 4), _Badge('Plus+', JuiceTheme.primaryTangerine)],
        if (user.isBanned) ...[const SizedBox(width: 4), _Badge('Banned', Colors.red)],
      ]),
      subtitle: Text(
        '${user.city} · ${user.age}y · ${user.email ?? 'no email'}',
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _ActionMenu(user: user, onAction: onAction),
    );
  }
}

// ── Web DataTable ─────────────────────────────────────────────────────────
class _UsersDataTable extends StatelessWidget {
  final List<JuiceUser> users;
  final Future<void> Function(String, JuiceUser) onAction;
  const _UsersDataTable({required this.users, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.surfaceContainerHighest),
          border: TableBorder.all(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8)),
          columns: const [
            DataColumn(label: Text('Avatar')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Age')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: users.map((user) {
            return DataRow(
              color: user.isBanned
                  ? WidgetStateProperty.all(Colors.red.withValues(alpha: 0.05))
                  : null,
              cells: [
                DataCell(CircleAvatar(
                  radius: 18,
                  backgroundImage:
                      user.photoUrl != null && user.photoUrl!.isNotEmpty
                          ? NetworkImage(user.photoUrl!)
                          : null,
                  backgroundColor:
                      JuiceTheme.primaryTangerine.withValues(alpha: 0.15),
                  child: user.photoUrl == null || user.photoUrl!.isEmpty
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 12))
                      : null,
                )),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(user.displayName,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  if (user.isAdmin) ...[
                    const SizedBox(width: 6),
                    _Badge('Admin', Colors.purple)
                  ],
                  if (user.isPremium) ...[
                    const SizedBox(width: 4),
                    _Badge('Plus+', JuiceTheme.primaryTangerine)
                  ],
                ])),
                DataCell(Text(user.email ?? '—',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(user.city)),
                DataCell(Text('${user.age}')),
                DataCell(user.isBanned
                    ? _Badge('Banned', Colors.red)
                    : _Badge('Active', Colors.green)),
                DataCell(_ActionMenu(user: user, onAction: onAction)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Shared pop-up action menu ─────────────────────────────────────────────
class _ActionMenu extends StatelessWidget {
  final JuiceUser user;
  final Future<void> Function(String, JuiceUser) onAction;
  const _ActionMenu({required this.user, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => onAction(action, user),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'view',
          child: _MenuItem(Icons.info_outline_rounded, 'View Profile'),
        ),
        PopupMenuItem(
          value: user.isBanned ? 'unban' : 'ban',
          child: _MenuItem(
            user.isBanned
                ? Icons.check_circle_outline_rounded
                : Icons.block_rounded,
            user.isBanned ? 'Unban User' : 'Ban User',
            color: user.isBanned ? Colors.green : Colors.orange,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: _MenuItem(Icons.delete_outline_rounded, 'Delete Account',
              color: Colors.red),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
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
            _row('UID', user.uid),
            _row('Email', user.email ?? '—'),
            _row('City', user.city),
            _row('Age', '${user.age}'),
            _row('Bio', user.bio ?? '—'),
            _row('Summary', user.juiceSummary),
            _row('Premium', user.isPremium ? 'Yes' : 'No'),
            _row('Photos', '${user.photos.length}'),
            _row('Banned', user.isBanned ? 'Yes' : 'No'),
            const Divider(height: 20),
            const Text('Juice Profile',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _profileBar('Family', p.family),
            _profileBar('Career', p.career),
            _profileBar('Lifestyle', p.lifestyle),
            _profileBar('Ethics', p.ethics),
            _profileBar('Fun', p.fun),
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

  Widget _row(String label, String value) {
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

  Widget _profileBar(String label, double value) {
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
