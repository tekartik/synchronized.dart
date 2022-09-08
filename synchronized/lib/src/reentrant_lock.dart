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
  Future<T> synchronized<T>(FutureOr<T> Function() func,
      {Duration? timeout, String? debugLabel}) async {
    // Handle late synchronized section warning
    final level = innerLevel;

    // Check that we are still in the proper block
    // zones could run outside the block so it could lead to an unexpected behavior
    if (level >= innerLocks.length) {
      throw StateError(
          'This can happen if an inner synchronized block is spawned outside the block it was started from. Make sure the inner synchronized blocks are properly awaited');
    }
    final lock = innerLocks[level];

    return lock.synchronized(() async {
      innerLocks.add(BasicLock());
      try {
        var result = runZoned(() async {
          debug(debugLabel, 'Executing synchronized function');
          final res = await func();
          debug(debugLabel, 'Executed synchronized function');
          return res;
        }, zoneValues: {this: level + 1});
        return await result;
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
}
