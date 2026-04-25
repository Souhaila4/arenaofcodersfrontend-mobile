import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/models/leaderboard_entry.dart';

/// Connects to the backend SSE endpoint and exposes a stream of
/// [LeaderboardUpdate] objects. Handles reconnection automatically.
class LeaderboardLiveService {
  final StorageService _storage = StorageService();
  http.Client? _client;
  StreamController<LeaderboardUpdate>? _controller;
  bool _disposed = false;

  /// The broadcast stream of leaderboard updates.
  Stream<LeaderboardUpdate> get updates {
    _controller ??= StreamController<LeaderboardUpdate>.broadcast(
      onListen: _connect,
      onCancel: _disconnect,
    );
    return _controller!.stream;
  }

  Future<void> _connect() async {
    if (_disposed) return;
    final token = await _storage.getToken();
    if (token == null) return;

    _client = http.Client();
    final url = Uri.parse('${ApiService.baseUrl}/competitions/leaderboard/live');

    try {
      final request = http.Request('GET', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        _scheduleReconnect();
        return;
      }

      // SSE format: each event is "data: {...json...}\n\n"
      String buffer = '';
      response.stream
          .transform(utf8.decoder)
          .listen(
        (chunk) {
          if (_disposed) return;
          buffer += chunk;
          // SSE events are separated by double-newline
          while (buffer.contains('\n\n')) {
            final idx = buffer.indexOf('\n\n');
            final rawEvent = buffer.substring(0, idx);
            buffer = buffer.substring(idx + 2);
            _parseEvent(rawEvent);
          }
        },
        onDone: () {
          if (!_disposed) _scheduleReconnect();
        },
        onError: (_) {
          if (!_disposed) _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (_) {
      if (!_disposed) _scheduleReconnect();
    }
  }

  void _parseEvent(String raw) {
    // SSE lines: "data: {json}" or "id: ..." or "event: ..."
    final lines = raw.split('\n');
    String jsonData = '';
    for (final line in lines) {
      if (line.startsWith('data:')) {
        jsonData += line.substring(5).trim();
      }
    }
    if (jsonData.isEmpty) return;
    try {
      final decoded = jsonDecode(jsonData) as Map<String, dynamic>;
      final update = LeaderboardUpdate.fromJson(decoded);
      if (!_disposed && _controller != null && !_controller!.isClosed) {
        _controller!.add(update);
      }
    } catch (_) {
      // Ignore malformed events
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _disconnect();
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed) _connect();
    });
  }

  void _disconnect() {
    _client?.close();
    _client = null;
  }

  /// Call this when the screen is disposed.
  void dispose() {
    _disposed = true;
    _disconnect();
    _controller?.close();
    _controller = null;
  }
}
