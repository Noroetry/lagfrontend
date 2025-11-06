import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal storage adapter to allow testing without depending directly on
/// FlutterSecureStorage in unit tests.
abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStorageAdapter implements SecureStorage {
  final FlutterSecureStorage _inner;
  FlutterSecureStorageAdapter([FlutterSecureStorage? inner]) : _inner = inner ?? const FlutterSecureStorage();

  @override
  Future<void> delete(String key) => _inner.delete(key: key);

  @override
  Future<String?> read(String key) => _inner.read(key: key);

  @override
  Future<void> write(String key, String value) => _inner.write(key: key, value: value);
}
