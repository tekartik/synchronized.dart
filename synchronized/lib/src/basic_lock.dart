import 'dart:async';

import 'package:synchronized/src/stack_trace_impl.dart';
import 'package:synchronized/synchronized.dart';

import 'stack.dart';

/// Basic (non-reentrant) lock
class BasicLock implements Lock {
  /// Creates a re-entrant lock
  /// If [enableStackTraces]  is set to true (default is false) then when
  /// a timeout occurs a stacktrace will be dumped for each synchronized
  /// block that is waiting on that lock.
  BasicLock({bool enableStackTraces = true})
      : _enableStackTraces = enableStackTraces;

  StackTraceImpl _stackTrace;
  final bool _enableStackTraces;

  /// The last running block
  _Block last;

  /// Stack of synchronized block waiting for a lock.
  /// We use this to dump stack traces if a timeout occurs
  /// in order to help diagnose locking issues.
  final Stack<_Block> _stack = Stack<_Block>();

  @override
  bool get locked => last != null;

  @override
  Future<T> synchronized<T>(FutureOr<T> Function() func,
      {Duration timeout}) async {
    final prev = last;
    final completer = Completer.sync();
    last = _Block(completer.future, enableStackTraces: _enableStackTraces);
    _stack.push(last);
    try {
      // If there is a previous running block, wait for it
      if (prev != null) {
        if (timeout != null) {
          // This could throw a timeout error
          await prev.future.timeout(timeout);
        } else {
          await prev.future;
        }
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
    } on TimeoutException catch (e, _) {
      if (_enableStackTraces) {
        print(
            'A Timeout occured waiting for a lock to complete. Stacktrace follows');
        print(_stackTrace.formatStackTrace());

        print(
            'The following synchronized blocks were waiting when the lock timed out:');
        for (var block in _stack) {
          print('********* BLOCK STARTS ************');
          print(block.stackTrace.formatStackTrace());
          print('********* BLOCK ENDS ************');
        }
      }
    } finally {
      // Cleanup
      // waiting for the previous task to be done in case of timeout
      void _complete() {
        // Only mark it unlocked when the last one complete
        if (identical(last.future, completer.future)) {
          last = null;
        }
        completer.complete();
      }

      // In case of timeout, wait for the previous one to complete too
      // before marking this task as complete

      if (prev != null && timeout != null) {
        // But we still returns immediately
        // ignore: unawaited_futures
        prev.future.then((_) {
          _complete();
        });
      } else {
        _complete();
      }
      _stack.pop();
    }
    return null;
  }

  @override
  String toString() {
    return 'Lock[${identityHashCode(this)}]';
  }

  @override
  bool get inLock => locked;
}

/// Used to track each active synchronized block.
class _Block {
  _Block(this.future, {bool enableStackTraces}) {
    if (enableStackTraces) {
      stackTrace = StackTraceImpl(skipFrames: 1);
    }
  }

  StackTraceImpl stackTrace;
  final Future<dynamic> future;
}
