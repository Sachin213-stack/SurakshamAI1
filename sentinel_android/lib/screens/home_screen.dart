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
          border: Border(top: BorderSide(color: Color(0xFF262626), width: 0.5)),
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
// Dashboard Tab - Instagram Style
// ══════════════════════════════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SentinelService>();
    final a = svc.analytics;

    return CustomScrollView(
      slivers: [
        // Instagram-style App Bar
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: Colors.black,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFF77737), Color(0xFFE1306C), Color(0xFFC13584)],
            ).createShader(bounds),
            child: const Text(
              'Sentinel',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 28),
                  onPressed: () {},
                ),
                if (svc.alerts.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE1306C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),

        // Stories-style Status Cards
        SliverToBoxAdapter(
          child: Container(
            height: 110,
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStoryCard(
                  'Status',
                  svc.isConnected ? '🟢' : '🔴',
                  svc.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  svc.isConnected ? 'Active' : 'Offline',
                ),
                _buildStoryCard(
                  'Threats',
                  '${a?.totalBlocked ?? 0}',
                  const Color(0xFFE1306C),
                  'Blocked',
                ),
                _buildStoryCard(
                  'Analyzed',
                  '${a?.totalAnalyzed ?? 0}',
                  const Color(0xFFF77737),
                  'Total',
                ),
                _buildStoryCard(
                  'Score',
                  '${a?.avgScore.toStringAsFixed(0) ?? 0}',
                  const Color(0xFFC13584),
                  'Average',
                ),
                _buildStoryCard(
                  'Today',
                  '${a?.scams24h ?? 0}',
                  const Color(0xFFFCAF45),
                  'Scams',
                ),
              ],
            ),
          ),
        ),

        // Quick Test Section
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
                  'Recent Alerts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
                return _buildAlertPost(context, svc.alerts[index]);
              },
              childCount: svc.alerts.isEmpty ? 1 : svc.alerts.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildStoryCard(String label, String value, Color color, String subtitle) {
    return Container(
      width: 95,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.25), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          width: 2,
          color: color.withOpacity(0.6),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E8E8E),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertPost(BuildContext context, AlertModel alert) {
    final isHighRisk = alert.score >= 80;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighRisk ? const Color(0xFFE1306C) : const Color(0xFF262626),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isHighRisk
                          ? [const Color(0xFFE1306C), const Color(0xFFC13584)]
                          : [const Color(0xFFF77737), const Color(0xFFFCAF45)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHighRisk ? Icons.warning_rounded : Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 22,
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Detected ${_timeAgo(alert.timestamp)}',
                        style: const TextStyle(
                          color: Color(0xFF8E8E8E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isHighRisk
                          ? [const Color(0xFFE1306C), const Color(0xFFC13584)]
                          : [const Color(0xFFF77737), const Color(0xFFFCAF45)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${alert.score}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Post Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.reasoning,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFFE0E0E0),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF262626)),
                  ),
                  child: Text(
                    alert.maskedText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E8E),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Safe'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8E8E8E),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.report_outlined, size: 20),
                    label: const Text('Report'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE1306C),
                      padding: const EdgeInsets.symmetric(vertical: 10),
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
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF77737), Color(0xFFE1306C), Color(0xFFC13584)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No threats detected yet.\nYou\'re protected 24/7.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E8E),
              fontSize: 15,
              height: 1.5,
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
// Quick Test Card - Instagram Story Style
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF77737), Color(0xFFE1306C)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science_outlined, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Test',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: DropdownButton<String>(
              value: _type,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: const Color(0xFF1A1A1A),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E8E)),
              items: const [
                DropdownMenuItem(value: 'sms', child: Text('📱 SMS Message')),
                DropdownMenuItem(value: 'call_transcript', child: Text('📞 Call Transcript')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste suspicious message here...',
              hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 14),
              filled: true,
              fillColor: Colors.black,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF262626)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF262626)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFF77737), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: svc.isAnalyzing ? null : () async {
                if (_ctrl.text.trim().isEmpty) return;
                await svc.analyze(_ctrl.text.trim(), _type);
                _ctrl.clear();
              },
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF77737), Color(0xFFE1306C), Color(0xFFC13584)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: svc.isAnalyzing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Analyze Now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
