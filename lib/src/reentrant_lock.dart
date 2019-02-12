import 'package:synchronized/src/lock_base.dart';

import 'utils.dart';

/// Reentrant lock
///
/// It uses [Zone] and maintain a list of inner futures
class ReentrantLock extends LockBase {
  // list of inner zones
  final List<Future> innerFutures = [];

  @override
  Future<T> synchronized<T>(FutureOr<T> func(), {Duration timeout}) async {
    if (inZone) {
      if (func != null) {
        final completer = Completer.sync();
        // Add a future to the completion list
        innerFutures.add(completer.future);
        try {
          return await func();
        } finally {
          // Remove it
          innerFutures.remove(completer.future);
          // Complete in case we are waiting for it
          completer.complete();
        }
      } else {
        return null;
      }
    } else {
      final prev = last;
      final completer = init();
      try {
        // If there is a previous running block, wait for it
        if (prev != null) {
          await waitPrevious(timeout, prev);
        }
        if (func != null) {
          // Run in a zone
          var result = runZoned(() {
            // Clear or futures
            innerFutures.clear();
            return func();
          }, zoneValues: {this: true});
          if (result is Future) {
            return await result;
          } else {
            return result;
          }
        } else {
          return null;
        }
      } finally {
        void _waitForInner() {
          // Await inner tasks
          if (innerFutures.isNotEmpty) {
            Future.wait(innerFutures).whenComplete(() {
              innerFutures.clear();
              complete(completer);
            });
          } else {
            complete(completer);
          }
        }

        cleanUp(prev, timeout, _waitForInner);
      }
    }
  }

  @override
  String toString() => 'ReentrantLock[${identityHashCode(this)}]';

  // We set a zone value to true
  bool get inZone => Zone.current[this] == true;

  @override
  bool get inLock => inZone;
}
