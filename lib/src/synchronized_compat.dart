import 'dart:async';

import 'package:synchronized/synchronized.dart';

import 'synchronized_impl.dart' as impl;

/// Kept for compatibilty a [SynchronizedLock] is a re-entrant [Lock]
@Deprecated("use Lock(renentrat: true) instead")
abstract class SynchronizedLock extends Lock {
  factory SynchronizedLock() {
    return impl.ReentrantLock();
  }

  /// returns true if we are in a synchronized zone already (i.e. inner)
  bool get inZone;
}

// ignore: non_generative_constructor, deprecated_member_use
abstract class SynchronizedLockCompat extends SynchronizedLock {
  factory SynchronizedLockCompat() {
    return impl.ReentrantLock();
  }
}

/// Deprecated: use [Lock.synchronized] instead.
///
/// Execute [computation] when lock is available. Only one fn can run while
/// the lock is retained. Any object can be a lock, locking is based on identity
/// If [reentrant] is true, it will use [Zone]
@Deprecated("Use Lock() instead")
Future<T> synchronized<T>(dynamic lock, FutureOr<T> computation(),
    {Duration timeout, bool reentrant = false}) {
  return impl.synchronized(lock, computation, timeout: timeout);
}
