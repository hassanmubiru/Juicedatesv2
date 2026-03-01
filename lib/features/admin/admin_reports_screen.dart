import 'package:flutter/material.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return StreamBuilder<List<JuiceReport>>(
      stream: service.getAllReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 80, color: Colors.green),
                SizedBox(height: 16),
                Text('No reports!',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('All content looks clean 🎉',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          if (isWide) {
            return _ReportsTable(reports: reports, service: service);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final report = reports[index];
              return _ReportCard(report: report, service: service);
            },
          );
        });
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final JuiceReport report;
  final FirestoreService service;

  const _ReportCard({required this.report, required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: report.resolved
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: report.resolved ? Colors.green : Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        report.resolved
                            ? Icons.check_circle_outlined
                            : Icons.pending_outlined,
                        size: 14,
                        color:
                            report.resolved ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        report.resolved ? 'Resolved' : 'Pending',
                        style: TextStyle(
                          color: report.resolved
                              ? Colors.green
                              : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _timeAgo(report.timestamp),
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _UidChip(
                    label: 'Reporter',
                    uid: report.reporterUid,
                    color: Colors.blue),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                _UidChip(
                    label: 'Reported',
                    uid: report.reportedUid,
                    color: Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${report.reason}"',
                style: const TextStyle(
                    fontStyle: FontStyle.italic, fontSize: 14),
              ),
            ),
            if (!report.resolved) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => service.banUser(report.reportedUid, ''),
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: const Text('Ban User'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => service.resolveReport(report.id),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Resolve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: JuiceTheme.juiceGreen,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ReportsTable extends StatelessWidget {
  final List<JuiceReport> reports;
  final FirestoreService service;
  const _ReportsTable({required this.reports, required this.service});

  @override
  Widget build(BuildContext context) {
    String timeAgo(DateTime dt) {
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }

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
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Reporter')),
            DataColumn(label: Text('Reported')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Actions')),
          ],
          rows: reports.map((r) {
            return DataRow(
              color: r.resolved
                  ? WidgetStateProperty.all(
                      Colors.green.withValues(alpha: 0.04))
                  : null,
              cells: [
                DataCell(Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.resolved ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: r.resolved ? Colors.green : Colors.orange),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      r.resolved
                          ? Icons.check_circle_outlined
                          : Icons.pending_outlined,
                      size: 14,
                      color: r.resolved ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      r.resolved ? 'Resolved' : 'Pending',
                      style: TextStyle(
                        color: r.resolved ? Colors.green : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                )),
                DataCell(Text(
                  r.reporterUid.length > 8
                      ? '${r.reporterUid.substring(0, 8)}…'
                      : r.reporterUid,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12),
                )),
                DataCell(Text(
                  r.reportedUid.length > 8
                      ? '${r.reportedUid.substring(0, 8)}…'
                      : r.reportedUid,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.red),
                )),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(r.reason,
                      overflow: TextOverflow.ellipsis, maxLines: 2),
                )),
                DataCell(Text(timeAgo(r.timestamp),
                    style: const TextStyle(color: Colors.grey))),
                DataCell(r.resolved
                    ? const Text('—',
                        style: TextStyle(color: Colors.grey))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        OutlinedButton(
                          onPressed: () => service.banUser(r.reportedUid, ''),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              visualDensity: VisualDensity.compact),
                          child: const Text('Ban'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: () => service.resolveReport(r.id),
                          style: FilledButton.styleFrom(
                              backgroundColor: JuiceTheme.juiceGreen,
                              visualDensity: VisualDensity.compact),
                          child: const Text('Resolve'),
                        ),
                      ])),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _UidChip extends StatelessWidget {
  final String label;
  final String uid;
  final Color color;

  const _UidChip(
      {required this.label, required this.uid, required this.color});

  @override
  Widget build(BuildContext context) {
    final short = uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(short,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                  fontFamily: 'monospace')),
        ),
      ],
    );
  }
}
