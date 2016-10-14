import '../synchronized.dart';
import 'dart:async';
import 'package:func/func.dart';

// utilities
@deprecated
devPrint(Object msg) {
  print(msg);
}

Future sleep(int ms) => new Future.delayed(new Duration(milliseconds: ms));

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
class SynchronizedLockImpl implements SynchronizedLock {
  Object monitor;
  SynchronizedLockImpl([this.monitor]);
  List<_SynchronizedTask> _tasks = new List();

  // return true if the block is currently locked
  bool get locked => _tasks.length > 0;

  Future/*<T>*/ synchronized/*<T>*/(Func0 fn, {timeout: null}) =>
      _synchronized(this, fn, timeout: timeout);

  @override
  String toString() => 'SynchronizedLock[${identityHashCode(this)}]';
}


// list of waiting/running locks
// empty when nothing running
Map<Object, SynchronizedLock> synchronizedLocks = {};

// Make any object a synchronized lock
SynchronizedLock makeSynchronizedLock(dynamic monitor) {
  if (monitor == null) {
    throw new ArgumentError('synchronized lock cannot be null');
  }

  // make lock a synchronizedLock object
  if (!(monitor is SynchronizedLock)) {
    // get or create Lock object
    SynchronizedLock synchronizedLock = synchronizedLocks[monitor];
    if (synchronizedLock == null) {
      synchronizedLock = new SynchronizedLock(monitor);
      synchronizedLocks[monitor] = synchronizedLock;
    }
    return synchronizedLock;
  }
  return monitor;
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

cleanupLock(SynchronizedLockImpl lock) {
  if (lock._tasks.isEmpty) {
    if (lock.monitor != null) {
      synchronizedLocks.remove(lock.monitor);
    }
  }
}
Future/*<T>*/ _synchronized/*<T>*/(SynchronizedLockImpl lock, Func0 fn, {timeout: null}) {
  List<_SynchronizedTask> tasks = lock._tasks;

  // Same zone means re-entrant, so run directly
  if (Zone.current[_zoneTag] == true) {
    return new Future/*<T>*/.sync(fn).whenComplete(() {
      cleanupLock(lock);
    });
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
      cleanupLock(lock);
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