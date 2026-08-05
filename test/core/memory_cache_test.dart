import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/cache/memory_cache.dart';

void main() {
  group('MemoryCache Tests', () {
    test('stores and retrieves cached values', () {
      final cache = MemoryCache<String, String>(
        ttl: const Duration(minutes: 5),
      );
      cache.put('key1', 'value1');
      expect(cache.get('key1'), equals('value1'));
    });

    test('returns null for missing key', () {
      final cache = MemoryCache<String, String>(
        ttl: const Duration(minutes: 5),
      );
      expect(cache.get('non_existent'), isNull);
    });

    test('invalidates specified key', () {
      final cache = MemoryCache<String, String>(
        ttl: const Duration(minutes: 5),
      );
      cache.put('key1', 'value1');
      cache.invalidate('key1');
      expect(cache.get('key1'), isNull);
    });

    test('invalidates all keys', () {
      final cache = MemoryCache<String, String>(
        ttl: const Duration(minutes: 5),
      );
      cache.put('k1', 'v1');
      cache.put('k2', 'v2');
      cache.invalidateAll();
      expect(cache.get('k1'), isNull);
      expect(cache.get('k2'), isNull);
    });

    test('evicts oldest when maxSize is reached', () {
      final cache = MemoryCache<String, int>(
        ttl: const Duration(minutes: 5),
        maxSize: 2,
      );
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3); // should evict 'a'

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), equals(2));
      expect(cache.get('c'), equals(3));
    });
  });
}
