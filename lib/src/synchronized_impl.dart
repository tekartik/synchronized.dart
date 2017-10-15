import '../synchronized.dart' as _;
import 'dart:async';

// utilities
@deprecated
devPrint(Object msg) {
  print(msg);
}

Future sleep(int ms) => new Future.delayed(new Duration(milliseconds: ms));

// A [SynchronizedTask] only complete when all precedent task complete
// i.e. in case of timeout
class SynchronizedTask {
  Completer completer = new Completer.sync();

  // Inner task, a task won't be marked as complete until all
  // its inner task are complete
  List<Future> innerFutures;

  // Add inner task if any
  addInnerFuture(Future future) {
    if (innerFutures == null) {
      innerFutures = [];
    }
    innerFutures.add(future);
    future.then((_) {
      innerFutures.remove(future);
      if (innerFutures.isEmpty) {
        innerFutures = null;
      }
    });
  }

  // Wait for the tasks and its inner ones
  Future get future => completer.future.whenComplete(() {
        // wait for inner
        if (innerFutures != null) {
          return Future.wait(innerFutures);
        }
      });

  SynchronizedTask();
}

// You can define synchonized lock object directly
// for convenient access
class SynchronizedLock implements _.SynchronizedLock {
  Object monitor;

  SynchronizedLock.impl([this.monitor]);

  factory SynchronizedLock([Object monitor]) {
    if (monitor == null) {
      return new SynchronizedLock.impl();
    } else {
      return makeSynchronizedLock(monitor);
    }
  }

  List<SynchronizedTask> tasks = new List();

  bool get inZone => (Zone.current[this] != null);

  // return true if the block is currently locked
  bool get locked => tasks.length > 0 && (!inZone);

  // testing only
  Future get ready {
    if (!locked) {
      return new Future.value();
    }
    return tasks.last.future;
  }

  // cleanup global map if needed
  void cleanUp() {
    cleanUpLock(this);
  }

  Future/*<T>*/ _run/*<T>*/(SynchronizedTask task, computation()) {
    return new Future.sync(() {
      return runZoned(() {
        if (computation != null) {
          return computation();
        }
      }, zoneValues: {this: task});
    });
  }

  Future/*<T>*/ _runInner/*<T>*/(computation()) {
    return new Future.sync(() {
      if (computation != null) {
        return computation();
      }
    });
  }

  Future cleanUpTask(SynchronizedTask task) {
    _cleanUp() {
      tasks.remove(task);
      cleanUp();
    }
    // mark as complete, wait for inner if any
    // and remove
    task.completer.complete();

    // wait for inner before cleaning
    if (task.innerFutures != null) {
      Future.wait(task.innerFutures).whenComplete(() {
        _cleanUp();
      });
    } else {
      _cleanUp();
    }
  }

  // implementation
  Future/*<T>*/ synchronized/*<T>*/(computation(), {Duration timeout}) {
    // Inner case scenario

    // If currently in a zone,
    // execute right away
    SynchronizedTask inZoneTask = Zone.current[this];
    if (inZoneTask != null) {
      Future innerFuture = _runInner(computation);
      inZoneTask.addInnerFuture(innerFuture);
      return innerFuture;
    }

    // get status before modifying our task list
    bool locked = this.locked;

    SynchronizedTask previousTask = locked ? tasks.last : null;

    // Create the task and add it to our queue
    SynchronizedTask task = new SynchronizedTask();
    tasks.add(task);

    Future/*<T>*/ run() {
      return _run/*<T>*/(task, computation).whenComplete(() {
        // return value is ignore here but we do want
        // to wait for the all the inner tasks to finished
        cleanUpTask(task);
      });
    }

    // When not locked, try to run in the most efficient way
    if (!locked) {
      // When not locked, try to run in the most efficient way
      return run();
    }

    // Handle timeout
    if (timeout != null) {
      //bool cancelled = false;
      return previousTask.future.timeout(timeout).then((_) {
        return run();
      }, onError: (e) {
        // timeout cleanup but don't wait for it
        // however we only mark this task as complete when the previous
        // did so that the next one is done at the proper time
        previousTask.future.whenComplete(() {
          cleanUpTask(task);
        });
        // keep the stack trace
        throw e;
      });
    }

    // Get the current running tasks (2 behind the one we just have added
    return previousTask.future.then((_) {
      return run();
    });
  }

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
      synchronizedLock = new SynchronizedLock.impl(monitor);
      synchronizedLocks[monitor] = synchronizedLock;
    }
    return synchronizedLock;
  }
  return monitor;
}

cleanUpLock(SynchronizedLock lock) {
  if (lock.tasks.isEmpty) {
    if (lock.monitor != null) {
      synchronizedLocks.remove(lock.monitor);
    }
  }
}

// Execute [computation] when lock is available. Only one block can run while
// the lock is retained. Any object can be a lock, locking is based on identity
Future/*<T>*/ synchronized/*<T>*/(dynamic lock, computation(),
    {timeout: null}) {
  // Make any object a lock object
  SynchronizedLock lockImpl = makeSynchronizedLock(lock);

  return lockImpl.synchronized(computation, timeout: timeout);
}
