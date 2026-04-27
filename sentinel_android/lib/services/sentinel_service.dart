import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AlertModel {
  final String id;
  final int score;
  final String action;
  final String reasoning;
  final String maskedText;
  final DateTime timestamp;

  AlertModel({
    required this.id,
    required this.score,
    required this.action,
    required this.reasoning,
    required this.maskedText,
    required this.timestamp,
  });

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
        id: j['id'] ?? '',
        score: j['score'] ?? 0,
        action: j['action'] ?? 'IGNORE',
        reasoning: j['reasoning'] ?? '',
        maskedText: j['masked_text'] ?? '',
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
      );

  Color get actionColor {
    if (action == 'BLOCK_CALL') return const Color(0xFFEF4444);
    if (action == 'OVERLAY_WARNING') return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }
}

class AnalyticsSummary {
  final int totalAnalyzed, totalBlocked, totalWarned, totalIgnored, scams24h;
  final double avgScore, blockRate;

  AnalyticsSummary({
    required this.totalAnalyzed, required this.totalBlocked,
    required this.totalWarned, required this.totalIgnored,
    required this.scams24h, required this.avgScore, required this.blockRate,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> j) => AnalyticsSummary(
        totalAnalyzed: j['total_analyzed'] ?? 0,
        totalBlocked: j['total_blocked'] ?? 0,
        totalWarned: j['total_warned'] ?? 0,
        totalIgnored: j['total_ignored'] ?? 0,
        scams24h: j['scams_last_24h'] ?? 0,
        avgScore: (j['avg_score'] ?? 0).toDouble(),
        blockRate: (j['block_rate_percent'] ?? 0).toDouble(),
      );
}

class SentinelService extends ChangeNotifier {
  String _apiUrl = 'http://10.0.2.2:8000'; // emulator localhost
  String _deviceId = 'android_device_001';
  String _apiKey = const String.fromEnvironment('API_KEY', defaultValue: '');

  List<AlertModel> alerts = [];
  AnalyticsSummary? analytics;
  bool isConnected = false;
  bool isAnalyzing = false;
  AlertModel? latestAlert;

  WebSocketChannel? _wsChannel;

  SentinelService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiUrl = prefs.getString('api_url') ?? _apiUrl;
    _deviceId = prefs.getString('device_id') ?? _deviceId;
    _apiKey = prefs.getString('api_key') ?? _apiKey;
    connectWebSocket();
    loadHistory();
    loadAnalytics();
  }

  Map<String, String> _jsonHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_apiKey.trim().isNotEmpty) {
      headers['X-API-Key'] = _apiKey.trim();
    }
    return headers;
  }

  void _upsertAlert(AlertModel alert) {
    final idx = alerts.indexWhere((a) => a.id == alert.id);
    if (idx >= 0) {
      alerts[idx] = alert;
    } else {
      alerts.insert(0, alert);
    }
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────
  void connectWebSocket() {
    try {
      final wsUrl = _apiUrl.replaceFirst('http', 'ws');
      _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/overlay/$_deviceId'));
      isConnected = true;
      notifyListeners();

      _wsChannel!.stream.listen(
        (data) {
          final json = jsonDecode(data);
          if (json['event'] == 'fraud_alert') {
            final normalized = {
              ...json,
              if (json['id'] == null && json['alert_id'] != null) 'id': json['alert_id'],
            };
            final alert = AlertModel.fromJson(normalized);
            latestAlert = alert;
            _upsertAlert(alert);
            notifyListeners();
          }
        },
        onDone: () {
          isConnected = false;
          notifyListeners();
          Future.delayed(const Duration(seconds: 3), connectWebSocket);
        },
        onError: (_) {
          isConnected = false;
          notifyListeners();
          Future.delayed(const Duration(seconds: 3), connectWebSocket);
        },
      );
    } catch (_) {
      isConnected = false;
      notifyListeners();
    }
  }

  // ── Analyze ───────────────────────────────────────────────────────────────
  Future<AlertModel?> analyze(String text, String type) async {
    isAnalyzing = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$_apiUrl/analyze'),
        headers: _jsonHeaders(),
        body: jsonEncode({'type': type, 'raw_text': text, 'device_id': _deviceId}),
      );
      if (res.statusCode == 200) {
        final alert = AlertModel.fromJson(jsonDecode(res.body));
        latestAlert = alert;
        _upsertAlert(alert);
        await loadAnalytics();
        notifyListeners();
        return alert;
      }
    } catch (_) {} finally {
      isAnalyzing = false;
      notifyListeners();
    }
    return null;
  }

  // ── History ───────────────────────────────────────────────────────────────
  Future<void> loadHistory() async {
    try {
      final res = await http.get(
        Uri.parse('$_apiUrl/alerts/history?page_size=50&device_id=$_deviceId'),
        headers: _jsonHeaders(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        alerts = (data['items'] as List).map((e) => AlertModel.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Analytics ─────────────────────────────────────────────────────────────
  Future<void> loadAnalytics() async {
    try {
      final res = await http.get(
        Uri.parse('$_apiUrl/analytics?device_id=$_deviceId'),
        headers: _jsonHeaders(),
      );
      if (res.statusCode == 200) {
        analytics = AnalyticsSummary.fromJson(jsonDecode(res.body));
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Feedback ──────────────────────────────────────────────────────────────
  Future<void> submitFeedback(String alertId, String feedback) async {
    try {
      await http.post(
        Uri.parse('$_apiUrl/alerts/feedback'),
        headers: _jsonHeaders(),
        body: jsonEncode({'alert_id': alertId, 'feedback': feedback, 'device_id': _deviceId}),
      );
    } catch (_) {}
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  Future<void> saveSettings(String apiUrl, String deviceId, String apiKey) async {
    _apiUrl = apiUrl;
    _deviceId = deviceId;
    _apiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', apiUrl);
    await prefs.setString('device_id', deviceId);
    await prefs.setString('api_key', apiKey);
    _wsChannel?.sink.close();
    connectWebSocket();
    notifyListeners();
  }

  String get apiUrl => _apiUrl;
  String get deviceId => _deviceId;
  String get apiKey => _apiKey;
}
