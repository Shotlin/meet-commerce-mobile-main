/// Drops duplicate and out-of-order realtime events.
///
/// The server stamps every `order:status` / `refund:status` event with a
/// strictly-increasing `seq` and a unique `eventId`. A client can receive an
/// event twice (socket redelivery across a reconnect, a push + a socket for
/// the same change) or out of order (a slow path overtaken by a fast one);
/// applying a stale one would roll the screen BACK to an older status. This
/// gate remembers, per key (order id / refund request id), the highest `seq`
/// applied and a bounded window of recent event ids.
///
/// Events without a `seq` (older backend) always pass — the REST reconcile
/// that follows every event is the ultimate source of truth.
class OrderEventGate {
  OrderEventGate({this.maxKeys = 500, this.maxEventIds = 400});

  final int maxKeys;
  final int maxEventIds;

  // Insertion-ordered => cheap LRU eviction of the oldest key.
  final Map<String, int> _lastSeq = <String, int>{};
  final List<String> _recentEventIds = <String>[];
  final Set<String> _recentEventIdSet = <String>{};

  /// Returns true when the event should be applied, and records it.
  bool accept({required String key, int? seq, String? eventId}) {
    if (eventId != null && eventId.isNotEmpty) {
      if (_recentEventIdSet.contains(eventId)) return false;
    }
    if (seq != null) {
      final last = _lastSeq[key];
      if (last != null && seq <= last) return false;
      _lastSeq.remove(key);
      _lastSeq[key] = seq;
      if (_lastSeq.length > maxKeys) {
        _lastSeq.remove(_lastSeq.keys.first);
      }
    }
    if (eventId != null && eventId.isNotEmpty) {
      _recentEventIds.add(eventId);
      _recentEventIdSet.add(eventId);
      if (_recentEventIds.length > maxEventIds) {
        _recentEventIdSet.remove(_recentEventIds.removeAt(0));
      }
    }
    return true;
  }

  void clear() {
    _lastSeq.clear();
    _recentEventIds.clear();
    _recentEventIdSet.clear();
  }
}
