import 'dart:async';

import 'package:synchronized/synchronized.dart' as common;

/// Basic (non-reentrant) lock
abstract class LockBase implements common.Lock {
  /// The last running block
  Future last;

  @override
  bool get locked => last != null;

  /// Called to init a new synchronized block
  Completer init() {
    final completer = Completer.sync();
    last = completer.future;
    return completer;
  }

  /// Called to complete a synchronized block
  void complete(Completer completer) {
    // Only mark it unlocked when the last one complete
    if (identical(last, completer.future)) {
      last = null;
    }
    completer.complete();
  }

  /// Wait for the previous task to complete before doing the next step
  void cleanUp(Future prev, Duration timeout, void Function() next) {
    // In case of timeout, wait for the previous one to complete too!
    if (prev != null && timeout != null) {
      // ignore: unawaited_futures
      prev.then((_) {
        next();
      });
    } else {
      next();
    }
  }

  /// Wait for the previous task.
  ///
  /// Can throw a [TimeoutException]
  Future waitPrevious(Duration timeout, Future prev) {
    if (timeout != null) {
      // This could throw a timeout error
      return prev.timeout(timeout);
    } else {
      return prev;
    }
  }
}
