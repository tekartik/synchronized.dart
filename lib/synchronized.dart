// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// This simulates the synchronized feature of Java
library synchronized;

import 'dart:async';
import 'src/synchronized_impl.dart' as impl;

// [SynchronizedLock] helper locker object. You don't need to use it directly as any object
// can act as 'monitor'. It provides over the [locked] and [sychronized]
// helper methods
abstract class SynchronizedLock {
  factory SynchronizedLock() {
    return new impl.SynchronizedLock();
  }

  // return true if the lock is currently locked
  bool get locked;

  // return true if we are in a synchronized zone already (i.e. inner)
  bool get inZone;

  // Execute [computation] when lock is available. Only one asynchronous block can run while
  // the lock is retained
  Future/*<T>*/ synchronized/*<T>*/(computation(), {Duration timeout});
}

// Execute [fn] when lock is available. Only one fn can run while
// the lock is retained. Any object can be a lock, locking is based on identity
Future/*<T>*/ synchronized/*<T>*/(dynamic lock, computation(),
    {Duration timeout}) {
  return impl.synchronized(lock, computation, timeout: timeout);
}
