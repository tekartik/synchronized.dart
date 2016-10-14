// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

/// This simulated the synchronized feature of Java
library synchronized;

import 'dart:async';
import 'package:func/func.dart';

// Private

// unique tag for the running synchronized zone
var _zoneTag = #tekartik_synchronized;

class _SynchronizedTask {
  Completer completer = new Completer.sync();
  Func0 fn;
  Future get future => completer.future;
  _SynchronizedTask(this.fn);
}

// You can define synchonized lock object directly
// for convenient access
class SynchronizedLock {
  Object monitor;
  SynchronizedLock([this.monitor]);
  List<_SynchronizedTask> _tasks = new List();

  // return true if the block is currently locked
  bool get locked => _tasks.length > 0;

  Future/*<T>*/ synchronized/*<T>*/(Func0 fn, {timeout: null}) =>
      _synchronized(this, fn, timeout: timeout);
}

// list of waiting/running locks
// empty when nothing running
Map<Object, SynchronizedLock> _synchronizedLocks = {};

// Make any object a synchronized lock
SynchronizedLock _makeSynchronizedLock(dynamic lock) {
  if (lock == null) {
    throw new ArgumentError('synchronized lock cannot be null');
  }

  // make lock a synchronizedLock object
  if (!(lock is SynchronizedLock)) {
    // get or create Lock object
    SynchronizedLock synchronizedLock = _synchronizedLocks[lock];
    if (synchronizedLock == null) {
      synchronizedLock = new SynchronizedLock();
      _synchronizedLocks[synchronizedLock];
    }
    lock = synchronizedLock;
  }
  return lock;
}

Future/*<T>*/ _run/*<T>*/(Func0 fn) {
  return new Future.sync(() {
    return runZoned(() {
      if (fn != null) {
        return fn();
      }
    }, zoneValues: {_zoneTag: true});
  });
}

Future/*<T>*/ _synchronized/*<T>*/(SynchronizedLock lock, Func0 fn, {timeout: null}) {
  List<_SynchronizedTask> tasks = lock._tasks;

  // Same zone means re-entrant, so run directly
  if (Zone.current[_zoneTag] == true) {
    return new Future.sync(fn);
  } else {
    // get status before modifying our task list
    bool locked = lock.locked;

    // Create the task and add it to our queue
    _SynchronizedTask task = new _SynchronizedTask(fn);
    tasks.add(task);

    _cleanup() {
      // Cleanup
      // remove from queue and complete
      tasks.remove(task);
      task.completer.complete();
    }

    Future/*<T>*/ run() {
      return _run/*<T>*/(fn).whenComplete(() {
        _cleanup();
      });
    }

    // When not locked, try to run in the most efficient way
    if (!locked) {
      // When not locked, try to run in the most efficient way
      return run();
    }

    // Get the current running tasks (2 behind the one we just have added
    _SynchronizedTask previousTask = tasks[tasks.length - 2];
    return previousTask.future.then((_) {
      return run();
    });
  }
}

Future/*<T>*/ synchronized/*<T>*/(dynamic lock, Func0 fn,
    {timeout: null}) async {
  // Make any object a lock object
  lock = _makeSynchronizedLock(lock);

  return _synchronized(lock, fn, timeout: timeout);
}
