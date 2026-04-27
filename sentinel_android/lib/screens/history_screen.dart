import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sentinel_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SentinelService>();

    return RefreshIndicator(
      onRefresh: svc.loadHistory,
      child: svc.alerts.isEmpty
        ? const Center(child: Text('No alerts yet', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: svc.alerts.length,
            itemBuilder: (_, i) => _HistoryCard(alert: svc.alerts[i]),
          ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AlertModel alert;
  const _HistoryCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = alert.actionColor;
    final time = '${alert.timestamp.hour.toString().padLeft(2,'0')}:${alert.timestamp.minute.toString().padLeft(2,'0')}';

    return Card(
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(alert.action.replaceAll('_', ' '),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            Text('Score: ${alert.score}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          Text(alert.reasoning, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(alert.maskedText,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(children: [
            _FeedbackBtn(
              label: '✓ Confirm Scam',
              color: const Color(0xFFEF4444),
              onTap: () => context.read<SentinelService>().submitFeedback(alert.id, 'confirmed_scam'),
            ),
            const SizedBox(width: 8),
            _FeedbackBtn(
              label: '✗ False Positive',
              color: Colors.grey,
              onTap: () => context.read<SentinelService>().submitFeedback(alert.id, 'false_positive'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _FeedbackBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FeedbackBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    ),
  );
}
