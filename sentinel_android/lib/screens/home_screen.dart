import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sentinel_service.dart';
import 'alert_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

// ignore: unused_import
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final _pages = const [
    _DashboardTab(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SentinelService>();

    // Show overlay alert when new high-score alert arrives
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alert = svc.latestAlert;
      if (alert != null && alert.score >= 80) {
        svc.latestAlert = null;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AlertScreen(alert: alert),
          fullscreenDialog: true,
        ));
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Row(children: [
          const Text('🛡️ ', style: TextStyle(fontSize: 20)),
          const Text('SENTINEL', style: TextStyle(
            color: Color(0xFFEF4444), fontWeight: FontWeight.w900,
            letterSpacing: 2,
          )),
          const Spacer(),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: svc.isConnected ? const Color(0xFF10B981) : Colors.grey,
              boxShadow: svc.isConnected ? [BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.5),
                blurRadius: 6,
              )] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            svc.isConnected ? 'Live' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              color: svc.isConnected ? const Color(0xFF10B981) : Colors.grey,
            ),
          ),
        ]),
      ),
      body: _pages[_tab],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF111827),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SentinelService>();
    final a = svc.analytics;

    return RefreshIndicator(
      onRefresh: () async {
        await svc.loadAnalytics();
        await svc.loadHistory();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Status Banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.security, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Protection Active', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15,
                )),
                Text('SMS & Calls monitored automatically',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Stats Grid ──
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _StatCard('${a?.totalAnalyzed ?? 0}', 'Analyzed', const Color(0xFF3B82F6)),
              _StatCard('${a?.totalBlocked ?? 0}', 'Blocked', const Color(0xFFEF4444)),
              _StatCard('${a?.totalWarned ?? 0}', 'Warned', const Color(0xFFF59E0B)),
              _StatCard('${a?.scams24h ?? 0}', 'Last 24h', const Color(0xFFEF4444)),
              _StatCard('${a?.avgScore.toStringAsFixed(0) ?? 0}', 'Avg Score', const Color(0xFFA78BFA)),
              _StatCard('${a?.blockRate.toStringAsFixed(0) ?? 0}%', 'Block Rate', const Color(0xFF10B981)),
            ],
          ),

          const SizedBox(height: 20),

          // ── Quick Test ──
          const Text('Quick Test', style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey,
            letterSpacing: 1,
          )),
          const SizedBox(height: 10),
          _QuickTestCard(),

          const SizedBox(height: 20),

          // ── Recent Alerts ──
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recent Alerts', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey,
              letterSpacing: 1,
            )),
            TextButton(
              onPressed: () {},
              child: const Text('See All', style: TextStyle(fontSize: 12)),
            ),
          ]),

          if (svc.alerts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 40),
                SizedBox(height: 8),
                Text('No threats detected yet', style: TextStyle(color: Colors.grey)),
              ]),
            )
          else
            ...svc.alerts.take(5).map((alert) => _AlertTile(alert: alert)),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCard(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF1F2937)),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value, style: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w900, color: color,
      )),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey),
        textAlign: TextAlign.center),
    ]),
  );
}

class _QuickTestCard extends StatefulWidget {
  @override
  State<_QuickTestCard> createState() => _QuickTestCardState();
}

class _QuickTestCardState extends State<_QuickTestCard> {
  final _ctrl = TextEditingController();
  String _type = 'sms';

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SentinelService>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButton<String>(
          value: _type,
          isExpanded: true,
          dropdownColor: const Color(0xFF1F2937),
          items: const [
            DropdownMenuItem(value: 'sms', child: Text('SMS')),
            DropdownMenuItem(value: 'call_transcript', child: Text('Call Transcript')),
          ],
          onChanged: (v) => setState(() => _type = v!),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Paste suspicious message here...',
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF0A0E1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1F2937)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: svc.isAnalyzing ? null : () async {
              if (_ctrl.text.trim().isEmpty) return;
              await svc.analyze(_ctrl.text.trim(), _type);
              _ctrl.clear();
            },
            child: svc.isAnalyzing
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Analyze', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertModel alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: alert.actionColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: alert.actionColor.withOpacity(0.3)),
          ),
          child: Center(child: Text('${alert.score}',
            style: TextStyle(color: alert.actionColor, fontWeight: FontWeight.w900, fontSize: 14))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(alert.action.replaceAll('_', ' '),
            style: TextStyle(color: alert.actionColor, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(alert.maskedText,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(alert.reasoning,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}
