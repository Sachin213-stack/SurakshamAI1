import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sentinel_service.dart';
import 'alert_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

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
      body: _pages[_tab],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF000000), width: 3)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined, size: 28),
              activeIcon: Icon(Icons.shield, size: 28),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined, size: 28),
              activeIcon: Icon(Icons.history, size: 28),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined, size: 28),
              activeIcon: Icon(Icons.settings, size: 28),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dashboard Tab - GenZ Style (Cream & Black)
// ══════════════════════════════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SentinelService>();
    final a = svc.analytics;

    return CustomScrollView(
      slivers: [
        // GenZ-style App Bar
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: const Color(0xFFFFFDF2),
          title: const Text(
            'sentinel',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF000000),
              letterSpacing: -1,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: svc.isConnected ? const Color(0xFF51CF66) : const Color(0xFF666666),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    svc.isConnected ? 'live' : 'offline',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFFDF2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Stats Grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildListDelegate([
              _buildStatCard(
                '${a?.totalBlocked ?? 0}',
                'threats blocked',
                const Color(0xFFFF6B6B),
              ),
              _buildStatCard(
                '${a?.totalAnalyzed ?? 0}',
                'total analyzed',
                const Color(0xFF000000),
              ),
              _buildStatCard(
                '${a?.totalIgnored ?? 0}',
                'marked safe',
                const Color(0xFF51CF66),
              ),
              _buildStatCard(
                '${a?.avgScore.toStringAsFixed(0) ?? 0}',
                'avg risk score',
                const Color(0xFFFFD93D),
              ),
            ]),
          ),
        ),

        // Quick Test Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _QuickTestCard(),
          ),
        ),

        // Recent Alerts Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'recent alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF000000),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'see all',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Alerts Feed
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (svc.alerts.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildAlertCard(context, svc.alerts[index]);
              },
              childCount: svc.alerts.isEmpty ? 1 : svc.alerts.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF2),
        border: Border.all(color: const Color(0xFF000000), width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF000000),
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, AlertModel alert) {
    final isHighRisk = alert.score >= 80;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF2),
        border: Border.all(
          color: isHighRisk ? const Color(0xFFFF6B6B) : const Color(0xFF000000),
          width: 3,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isHighRisk ? const Color(0xFFFF6B6B) : const Color(0xFF000000),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE8E6DD),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isHighRisk ? const Color(0xFFFF6B6B) : const Color(0xFF000000),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHighRisk ? Icons.warning_rounded : Icons.info_outline_rounded,
                    color: const Color(0xFFFFFDF2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.action.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        _timeAgo(alert.timestamp),
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isHighRisk ? const Color(0xFFFF6B6B) : const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${alert.score}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFFFFFDF2),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.reasoning,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF000000),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E6DD),
                    border: Border.all(color: const Color(0xFF000000), width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    alert.maskedText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF000000), width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('safe'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF000000),
                      side: const BorderSide(color: Color(0xFF000000), width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.report_outlined, size: 20),
                    label: const Text('report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: const Color(0xFFFFFDF2),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF000000), width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFFE8E6DD),
                  offset: Offset(6, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 70,
              color: Color(0xFFFFFDF2),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'all clear!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'no threats detected yet.\nyou\'re protected 24/7.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'recently';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Quick Test Card - GenZ Style
// ══════════════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF000000), width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '🧪',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'test it out',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFFDF2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFFDF2), width: 2),
            ),
            child: DropdownButton<String>(
              value: _type,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: const Color(0xFFFFFDF2),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF000000)),
              items: const [
                DropdownMenuItem(value: 'sms', child: Text('📱 sms message')),
                DropdownMenuItem(value: 'call_transcript', child: Text('📞 call transcript')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, color: Color(0xFF000000)),
            decoration: InputDecoration(
              hintText: 'paste suspicious message here...',
              hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFFFFDF2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFFDF2), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFFDF2), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFD93D), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFFDF2),
                foregroundColor: const Color(0xFF000000),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: svc.isAnalyzing ? null : () async {
                if (_ctrl.text.trim().isEmpty) return;
                await svc.analyze(_ctrl.text.trim(), _type);
                _ctrl.clear();
              },
              child: svc.isAnalyzing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF000000),
                      ),
                    )
                  : const Text(
                      'analyze now',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
