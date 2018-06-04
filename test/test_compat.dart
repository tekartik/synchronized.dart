// Create a reentrant lock (use Zone)
import 'package:synchronized/synchronized.dart';
import 'package:synchronized/src/synchronized_impl.dart' as impl;

import 'test_common.dart';

class SynchronizedLockFactory implements LockFactory {
  @override
  Lock newLock() => new impl.ReentrantLock();
}
