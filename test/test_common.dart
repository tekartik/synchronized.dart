import 'dart:async';

import 'package:synchronized/synchronized.dart';
export 'package:synchronized/src/utils.dart';

// Create by default a non-reentrant lock
class LockFactory {
  Lock newLock() => Lock();
}

bool _isDart2AsyncTiming;
Future<bool> isDart2AsyncTiming() async {
  if (_isDart2AsyncTiming == null) {
    // Create an async function
    // in dart1 the first line won't be executed directly
    // in dart2 it should
    Future method() async {
      if (_isDart2AsyncTiming == null) {
        _isDart2AsyncTiming = true;
      }
    }

    // Calling the async function not waiting for it
    // ignore: unawaited_futures
    method();
    if (_isDart2AsyncTiming == null) {
      _isDart2AsyncTiming = false;
    }
  }
  return _isDart2AsyncTiming;
}
