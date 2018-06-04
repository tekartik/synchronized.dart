import 'dart:async';

import 'package:synchronized/synchronized.dart';

import 'synchronized_impl.dart' as impl;

// [SynchronizedLock] helper locker object. You don't need to use it directly as any object
// can act as 'monitor'. It provides over the [locked] and [sychronized]
// helper methods
// It uses [Zone] to allow being reentrant
// use Lock(renentrat: true) instead
@deprecated
abstract class SynchronizedLock extends Lock {
  factory SynchronizedLock() {
    return new impl.ReentrantLock();
  }

  // return true if we are in a synchronized zone already (i.e. inner)
  bool get inZone;
}

// ignore: non_generative_constructor, deprecated_member_use
abstract class SynchronizedLockCompat extends SynchronizedLock {}

// Execute [fn] when lock is available. Only one fn can run while
// the lock is retained. Any object can be a lock, locking is based on identity
// If [reentrant] is true, it will use [Zone]
@deprecated
Future<T> synchronized<T>(dynamic lock, FutureOr<T> computation(),
    {Duration timeout, bool reentrant = false}) {
  return impl.synchronized(lock, computation, timeout: timeout);
}
