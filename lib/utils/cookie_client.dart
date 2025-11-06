import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A small HTTP client wrapper that persistently stores cookies (name=value)
/// and sends them with subsequent requests. This allows us to rely on server-set
/// HttpOnly cookies (refresh tokens) across requests in the mobile app.
class CookieClient extends http.BaseClient {
  final http.Client _inner;
  final FlutterSecureStorage _storage;

  // In-memory cookie store: name -> value
  final Map<String, String> _cookies = {};

  // Storage key
  static const _kCookieStoreKey = 'cookie_store';

  CookieClient({http.Client? inner, FlutterSecureStorage? storage})
      : _inner = inner ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<void> _loadFromStorage() async {
    try {
      final raw = await _storage.read(key: _kCookieStoreKey);
      if (raw == null || raw.trim().isEmpty) return;
      // raw format: name=value; name2=value2
      final parts = raw.split(';');
      for (final part in parts) {
        final p = part.trim();
        if (p.isEmpty) continue;
        final idx = p.indexOf('=');
        if (idx <= 0) continue;
        final name = p.substring(0, idx);
        final value = p.substring(idx + 1);
        _cookies[name] = value;
      }
    } catch (_) {}
  }

  Future<void> _saveToStorage() async {
    try {
      if (_cookies.isEmpty) {
        await _storage.delete(key: _kCookieStoreKey);
        return;
      }
      final raw = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      await _storage.write(key: _kCookieStoreKey, value: raw);
    } catch (_) {}
  }

  /// Clears stored cookies both in memory and persistent storage.
  Future<void> clearCookies() async {
    _cookies.clear();
    try {
      await _storage.delete(key: _kCookieStoreKey);
    } catch (_) {}
  }

  String? _buildCookieHeader() {
    if (_cookies.isEmpty) return null;
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Ensure persisted cookies are loaded once
    if (_cookies.isEmpty) await _loadFromStorage();

    final cookieHeader = _buildCookieHeader();
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      request.headers['Cookie'] = cookieHeader;
    }

    final streamed = await _inner.send(request);

    // Read set-cookie header(s) from response and update store.
    try {
      final sc = streamed.headers['set-cookie'];
      if (sc != null && sc.isNotEmpty) {
        // Extract name=value pairs using a simple regex; ignore flags like HttpOnly, Path, Expires
        final reg = RegExp(r'([^=;,\s]+)=([^;,\s]+)');
        final matches = reg.allMatches(sc);
        for (final m in matches) {
          final name = m.group(1);
          final value = m.group(2);
          if (name != null && value != null) {
            _cookies[name] = value;
          }
        }
        // persist
        unawaited(_saveToStorage());
      }
    } catch (_) {}

    return streamed;
  }
}
