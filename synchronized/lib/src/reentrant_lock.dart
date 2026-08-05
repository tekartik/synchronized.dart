import 'package:synchronized/src/basic_lock.dart';
import 'package:synchronized/synchronized.dart';

import 'utils.dart';

/// Reentrant lock.
///
/// It uses [Zone] and maintain a list of inner locks.
class ReentrantLock implements Lock {
  /// We always have at least one inner lock
  final List<BasicLock> innerLocks = [BasicLock()];

  /// Inner level count.
  int get innerLevel => (Zone.current[this] as int?) ?? 0;

  @override
  Future<T> synchronized<T>(
    FutureOr<T> Function() func, {
    Duration? timeout,
  }) async {
    // Handle late synchronized section warning
    final level = innerLevel;
    _checkLevel(level);
    final lock = innerLocks[level];

    return lock.synchronized(() async {
      innerLocks.add(BasicLock());
      try {
        var result = runZoned(() {
          return func();
        }, zoneValues: {this: level + 1});
        if (result is Future) {
          return await result;
        } else {
          return result;
        }
      } finally {
        innerLocks.removeLast();
      }
    }, timeout: timeout);
  }

  @override
  String toString() => 'ReentrantLock[${identityHashCode(this)}]';

  /// We are in zone as soon as we enter the first lock level.
  bool get inZone => innerLevel > 0;

  @override
  bool get inLock => inZone;

  @override
  bool get locked => innerLocks.length > 1;

  /// Check that we are still in the proper block.
  ///
  /// Zones can run outside the block they were created for, so a captured
  /// zone may report a level that has since been popped from [innerLocks].
  /// Indexing with it would throw an opaque `RangeError`, so fail with the
  /// same explanation [synchronized] gives.
  void _checkLevel(int level) {
    if (level >= innerLocks.length) {
      throw StateError(
        'This can happen if an inner synchronized block is spawned outside the block it was started from. Make sure the inner synchronized blocks are properly awaited',
      );
    }
  }

  @override
  bool get canLock {
    // Validated unconditionally: a stale zone cannot lock whatever `locked`
    // says, so short-circuiting on `!locked` here would report `true` for a
    // call that is about to throw.
    final level = innerLevel;
    _checkLevel(level);
    return !locked || !innerLocks[level].locked;
  }
}
