import 'dart:async';

import 'package:synchronized/src/lock_base.dart';

/// Basic (non-reentrant) lock
class BasicLock extends LockBase {
  @override
  Future<T> synchronized<T>(FutureOr<T> func(), {Duration timeout}) async {
    final prev = last;
    final completer = init();
    try {
      // If there is a previous running block, wait for it
      if (prev != null) {
        await waitPrevious(timeout, prev);
      }

      // Run the function and return the result
      if (func != null) {
        var result = func();
        if (result is Future) {
          return await result;
        } else {
          return result;
        }
      } else {
        return null;
      }
    } finally {
      // Cleanup
      // waiting for the previous task to be done in case of timeout
      void _complete() {
        complete(completer);
      }

      cleanUp(prev, timeout, _complete);
    }
  }

  @override
  String toString() {
    return 'Lock[${identityHashCode(this)}]';
  }

  @override
  bool get inLock => locked;
}
