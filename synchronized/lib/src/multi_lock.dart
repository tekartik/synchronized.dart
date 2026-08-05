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
  /// Creates a lock that acquires every lock in `locks` together.
  ///
  /// [_locks] is iterated once per [synchronized] call, in order, to acquire
  /// (and, in reverse, to release) each underlying lock.
  MultiLock({required this._locks});

  final Iterable<Lock> _locks;

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
    FutureOr<T> runWithLocks(Iterator<Lock> iterator) {
      if (!iterator.moveNext()) {
        return computation();
      } else {
        final currentLock = iterator.current;
        return currentLock.synchronized(
          () => runWithLocks(iterator),
          timeout: timeout,
        );
      }
    }

    return runWithLocks(_locks.iterator);
  }

  @override
  String toString() => 'MultiLock[${identityHashCode(this)}]';
}
