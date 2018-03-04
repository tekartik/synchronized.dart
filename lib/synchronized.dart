// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// This simulates the synchronized feature of Java
library synchronized;

import 'dart:async';
import 'src/synchronized_impl.dart' as impl;

// [SynchronizedLock] helper locker object. You don't need to use it directly as any object
// can act as 'monitor'. It provides over the [locked] and [sychronized]
// helper methods
// It uses [Zone] to allow being reentrant
abstract class SynchronizedLock extends Lock {
  factory SynchronizedLock() {
    return new impl.SynchronizedLock();
  }

  // return true if we are in a synchronized zone already (i.e. inner)
  bool get inZone;
}

// [Lock] can be reentrant (in this cas it will used [SynchronizedLock] hence a [Zone]
// non-reentrant is to be used like an aync executor with a capaticity of 1
abstract class Lock {
  // Execute [computation] when lock is available. Only one asynchronous block can run while
  // the lock is retained
  Future<T> synchronized<T>(FutureOr<T> computation(), {Duration timeout});

  // return true if the lock is currently locked
  bool get locked;

  factory Lock({bool reentrant = false}) {
    if (reentrant == true) {
      return new impl.SynchronizedLock();
    } else {
      return new impl.Lock();
    }
  }
}

// Execute [fn] when lock is available. Only one fn can run while
// the lock is retained. Any object can be a lock, locking is based on identity
// If [reentrant] is true, it will use [Zone]
Future<T> synchronized<T>(dynamic lock, FutureOr<T> computation(),
    {Duration timeout, bool reentrant = false}) {
  return impl.synchronized(lock, computation, timeout: timeout);
}
