import 'package:synchronized/synchronized.dart';
export 'package:synchronized/src/utils.dart';

// Create by default a non-reentrant lock
class LockFactory {
  Lock newLock() => new Lock();
}

// Create a reentrant lock (use Zone)
class SynchronizedLockFactory extends LockFactory {
  @override
  Lock newLock() => new SynchronizedLock();
}
