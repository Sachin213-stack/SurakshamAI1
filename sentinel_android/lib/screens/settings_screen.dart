import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sentinel_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiCtrl;
  late TextEditingController _deviceCtrl;

  @override
  void initState() {
    super.initState();
    final svc = context.read<SentinelService>();
    _apiCtrl = TextEditingController(text: svc.apiUrl);
    _deviceCtrl = TextEditingController(text: svc.deviceId);
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SentinelService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Connection ──
        _SectionHeader('Connection'),
        _SettingCard(children: [
          _Field('Backend API URL', _apiCtrl, hint: 'http://10.0.2.2:8000'),
          const SizedBox(height: 12),
          _Field('Device ID', _deviceCtrl, hint: 'android_device_001'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () async {
                await svc.saveSettings(_apiCtrl.text.trim(), _deviceCtrl.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved & reconnected')));
              },
              child: const Text('Save & Reconnect'),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        // ── Status ──
        _SectionHeader('System Status'),
        _SettingCard(children: [
          _StatusRow('Backend Connection', svc.isConnected),
          const Divider(color: Color(0xFF1F2937)),
          _StatusRow('SMS Monitoring', true),
          const Divider(color: Color(0xFF1F2937)),
          _StatusRow('Call Screening', true),
          const Divider(color: Color(0xFF1F2937)),
          _StatusRow('Background Service', true),
        ]),

        const SizedBox(height: 20),

        // ── Thresholds ──
        _SectionHeader('Detection Thresholds'),
        _SettingCard(children: [
          _ThresholdRow('Block Threshold', 80, const Color(0xFFEF4444)),
          const SizedBox(height: 8),
          _ThresholdRow('Warn Threshold', 50, const Color(0xFFF59E0B)),
        ]),

        const SizedBox(height: 20),

        // ── About ──
        _SectionHeader('About'),
        _SettingCard(children: [
          _InfoRow('App Version', '1.0.0'),
          const Divider(color: Color(0xFF1F2937)),
          _InfoRow('Model', 'Llama 3.3 70B (Groq)'),
          const Divider(color: Color(0xFF1F2937)),
          _InfoRow('Privacy', 'SpaCy NER + Regex'),
          const Divider(color: Color(0xFF1F2937)),
          _InfoRow('Memory', 'Pinecone Vector DB'),
        ]),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title.toUpperCase(), style: const TextStyle(
      color: Colors.grey, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold,
    )),
  );
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1F2937)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  const _Field(this.label, this.ctrl, {required this.hint});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
        filled: true, fillColor: const Color(0xFF0A0E1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ]);
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool active;
  const _StatusRow(this.label, this.active);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: (active ? const Color(0xFF10B981) : Colors.grey).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(active ? 'Active' : 'Inactive',
          style: TextStyle(
            color: active ? const Color(0xFF10B981) : Colors.grey,
            fontSize: 11, fontWeight: FontWeight.bold,
          )),
      ),
    ]),
  );
}

class _ThresholdRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ThresholdRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 13)),
    const Spacer(),
    Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
  ]);
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13)),
    ]),
  );
}
