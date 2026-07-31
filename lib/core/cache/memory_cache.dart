/// In-memory generic cache with TTL and LRU eviction policy.
///
/// Designed as a shared abstraction so repositories do not manage raw Maps.
final class MemoryCache<K, V> {
  final Duration ttl;
  final int maxSize;
  final Map<K, ({DateTime insertedAt, V value})> _store = {};

  MemoryCache({required this.ttl, this.maxSize = 100});

  V? get(K key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.insertedAt) > ttl) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  void put(K key, V value) {
    if (_store.length >= maxSize && !_store.containsKey(key)) {
      _evictOldest();
    }
    _store[key] = (insertedAt: DateTime.now(), value: value);
  }

  void invalidate(K key) => _store.remove(key);

  void invalidateAll() => _store.clear();

  void _evictOldest() {
    if (_store.isEmpty) return;
    K? oldestKey;
    DateTime? oldestTime;

    for (final entry in _store.entries) {
      if (oldestTime == null || entry.value.insertedAt.isBefore(oldestTime)) {
        oldestTime = entry.value.insertedAt;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _store.remove(oldestKey);
    }
  }
}
