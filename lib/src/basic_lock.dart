import 'dart:async';

import 'package:synchronized/synchronized.dart' as common;

/// Basic (non-reentrant) lock
class BasicLock implements common.Lock {
  // The last running block
  Future last;

  @override
  bool locked = false;

  @override
  Future<T> synchronized<T>(FutureOr<T> func(), {Duration timeout}) async {
    final prev = last;
    final completer = Completer.sync();
    last = completer.future;
    try {
      // If there is a previous running block, wait for it
      if (prev != null) {
        if (timeout != null) {
          // This could throw a timeout error
          await prev.timeout(timeout);
        } else {
          await prev;
        }
      }
      if (func != null) {
        // Marked as locked
        locked = true;
        return await func();
      } else {
        return null;
      }
    } finally {
      // Only mark it unlocked when the last one complete
      if (last == completer.future) {
        locked = false;
      }

      // Complete the last future when needed
      // In case of timeout, wait for the previous one to complete too!
      if (prev != null && timeout != null) {
        // ignore: unawaited_futures
        prev.then((_) {
          completer.complete();
        });
      } else {
        completer.complete();
      }
    }
  }

  @override
  String toString() {
    return 'Lock[${identityHashCode(this)}]';
  }

  @override
  bool get inLock => locked;
}
