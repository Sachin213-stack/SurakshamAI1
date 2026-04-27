import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sentinel_service.dart';

/// Full-screen red overlay alert — shown when score >= 80
class AlertScreen extends StatelessWidget {
  final AlertModel alert;
  const AlertScreen({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final isBlock = alert.action == 'BLOCK_CALL';
    final color = isBlock ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Red pulsing background
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [color.withOpacity(0.15), Colors.black],
              radius: 1.2,
            ),
          ),
        ),

        // Border glow
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Icon(
                  isBlock ? Icons.block : Icons.warning_amber_rounded,
                  color: color, size: 72,
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  isBlock ? '🚨 CALL BLOCKED' : '⚠️ FRAUD WARNING',
                  style: TextStyle(
                    color: color, fontSize: 24,
                    fontWeight: FontWeight.w900, letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),

                // Score
                Text(
                  'Risk Score: ${alert.score}/100',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 24),

                // Score bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: alert.score / 100,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 24),

                // Reasoning card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Why flagged:', style: TextStyle(
                      color: Colors.grey[400], fontSize: 11,
                      letterSpacing: 1, fontWeight: FontWeight.bold,
                    )),
                    const SizedBox(height: 6),
                    Text(alert.reasoning, style: const TextStyle(
                      color: Colors.white, fontSize: 14,
                    )),
                  ]),
                ),
                const SizedBox(height: 12),

                // Masked text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Text(
                    alert.maskedText,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),

                const SizedBox(height: 32),

                // Dismiss
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('I Understand — Dismiss',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 10),

                // False positive
                TextButton(
                  onPressed: () {
                    context.read<SentinelService>().submitFeedback(alert.id, 'false_positive');
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marked as safe. Thank you!')),
                    );
                  },
                  child: const Text('Mark as Safe (False Positive)',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
