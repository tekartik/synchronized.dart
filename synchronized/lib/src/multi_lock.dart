import 'dart:async';

import 'package:synchronized/synchronized.dart';

/// A [Lock] that atomically acquires several other locks together.
///
/// [synchronized] acquires each underlying lock in the order given to
/// [MultiLock.new], running the computation once all of them are held, then
/// releases them in reverse order. To avoid deadlocks, always acquire the
/// same set of underlying locks in the same relative order across every
/// [MultiLock] (or direct [Lock.synchronized] call) that shares any of them.
class MultiLock implements Lock {
  /// Creates a lock that acquires every lock in [locks] together.
  ///
  /// [locks] is copied, so the lock set is fixed at construction: iterating
  /// it later must not be able to yield a different result. Passing a lazy
  /// [Iterable] that rebuilds its elements on each iteration would otherwise
  /// mean acquiring a different lock every time, silently providing no
  /// mutual exclusion at all.
  ///
  /// The captured list is walked in order on each [synchronized] call to
  /// acquire (and, in reverse, to release) each underlying lock.
  MultiLock({required Iterable<Lock> locks}) : _locks = List<Lock>.of(locks);

  final List<Lock> _locks;

  @override
  bool get canLock => _locks.every((it) => it.canLock);

  @override
  bool get inLock => _locks.every((it) => it.inLock);

  @override
  bool get locked => _locks.every((it) => it.locked);

  @override
  Future<T> synchronized<T>(
    FutureOr<T> Function() computation, {
    Duration? timeout,
  }) async {
    // [timeout] bounds the whole acquisition, not each lock in turn, so the
    // budget is spent against a single stopwatch. Passing [timeout] down
    // unchanged would let a caller wait up to `locks.length * timeout`.
    final stopwatch = timeout == null ? null : (Stopwatch()..start());

    Duration? remaining() {
      if (timeout == null) {
        return null;
      }
      final left = timeout - stopwatch!.elapsed;
      // A non-positive budget must still time out rather than wait forever.
      return left > Duration.zero ? left : Duration.zero;
    }

    FutureOr<T> runWithLocks(Iterator<Lock> iterator) {
      if (!iterator.moveNext()) {
        return computation();
      } else {
        final currentLock = iterator.current;
        return currentLock.synchronized(
          () => runWithLocks(iterator),
          timeout: remaining(),
        );
      }
    }

    return runWithLocks(_locks.iterator);
  }

  @override
  String toString() => 'MultiLock[${identityHashCode(this)}]';
}
