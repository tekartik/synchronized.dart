import 'package:synchronized/synchronized.dart';

// Create by default a non-reentrant lock
class LockFactory {
  Lock newLock() => new Lock();
}

// Create a reentrant lock (use Zone)
class SynchronizedLockFactory extends LockFactory {
  @override
  Lock newLock() => new SynchronizedLock();
}
