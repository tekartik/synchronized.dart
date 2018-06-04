// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// This simulates the synchronized feature of Java
library synchronized;

import 'dart:async';
import 'src/synchronized_impl.dart' as impl;
// ignore: deprecated_member_use
export 'src/synchronized_compat.dart' show SynchronizedLock, synchronized;

// [Lock] can be reentrant (in this cas it will used [SynchronizedLock] hence a [Zone]
// non-reentrant is to be used like an aync executor with a capaticity of 1
abstract class Lock {
  // Execute [computation] when lock is available. Only one asynchronous block can run while
  // the lock is retained
  Future<T> synchronized<T>(FutureOr<T> computation(), {Duration timeout});

  // return true if the lock is currently locked
  bool get locked;

  // for reentrant, test whether we are currently in the synchronized section
  // for non reentrant, it returns the [locked] status
  bool get inLock;

  factory Lock({bool reentrant = false}) {
    if (reentrant == true) {
      return new impl.ReentrantLock();
    } else {
      return new impl.Lock();
    }
  }
}
