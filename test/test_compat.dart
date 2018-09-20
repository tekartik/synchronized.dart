// Create a reentrant lock (use Zone)
import 'package:synchronized/synchronized.dart';
import 'package:synchronized/src/synchronized_impl.dart' as impl;

import 'test_common.dart';

@deprecated
class SynchronizedLockFactory implements LockFactory {
  @override
  Lock newLock() => impl.ReentrantLock();
}

class ReentrantLockFactory implements LockFactory {
  @override
  Lock newLock() => impl.ReentrantLock();
}
