import 'dart:async';

import 'package:synchronized/synchronized.dart';

/// A multi lock that locks multiple locks at the same time.
class MultiLock implements Lock {
  final Iterable<Lock> _locks;

  /// Creates a new multi lock.
  MultiLock({required Iterable<Lock> locks}) : _locks = locks;

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
}
