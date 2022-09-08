import 'dart:async';

import 'package:synchronized/src/utils.dart';
import 'package:synchronized/synchronized.dart';

/// Basic (non-reentrant) lock
class BasicLock implements Lock {
  /// The last running block
  Future<dynamic>? last;

  @override
  bool get locked => last != null;

  @override
  Future<T> synchronized<T>(FutureOr<T> Function() func,
      {Duration? timeout, String? debugLabel}) async {
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

      // Run the function and return the result
      debug(debugLabel, 'Executing synchronized function');
      final result = await func();
      debug(debugLabel, 'Executed synchronized function');
      return result;
    } finally {
      // Cleanup
      // waiting for the previous task to be done in case of timeout
      void complete() {
        // Only mark it unlocked when the last one complete
        if (identical(last, completer.future)) {
          last = null;
        }
        completer.complete();
      }

      // In case of timeout, wait for the previous one to complete too
      // before marking this task as complete

      if (prev != null && timeout != null) {
        // But we still returns immediately
        // ignore: unawaited_futures
        prev.then((_) {
          complete();
        });
      } else {
        complete();
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
