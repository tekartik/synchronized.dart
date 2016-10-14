// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

/// This simulated the synchronized feature of Java
library synchronized;

import 'dart:async';
import 'package:func/func.dart';
import 'src/synchronized_impl.dart' as impl;

// [SynchronizedLock] helper locker object. You don't need to use it directly as any object
// can act as 'monitor'. It provides over the [locked] and [sychronized]
// helper methods
abstract class SynchronizedLock {
  factory SynchronizedLock([Object monitor]) {
    return new impl.SynchronizedLock(monitor);
  }

  // return true if the lock is currently locked
  bool get locked;

  // Execute [fn] when lock is available. Only one fn can run while
  // the lock is retained
  Future/*<T>*/ synchronized/*<T>*/(Func0 fn, {timeout: null});
}

// Execute [fn] when lock is available. Only one fn can run while
// the lock is retained. Any object can be a lock, locking is based on identity
Future/*<T>*/ synchronized/*<T>*/(dynamic lock, Func0 fn, {timeout: null}) {
  return impl.synchronized(lock, fn, timeout: timeout);
}
