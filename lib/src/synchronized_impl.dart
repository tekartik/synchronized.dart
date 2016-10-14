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
  Future get future => completer.future;
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

  bool get inZone => (Zone.current[this] == true);
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

  Future/*<T>*/ _run/*<T>*/(computation()) {
    return new Future.sync(() {
      return runZoned(() {
        if (computation != null) {
          return computation();
        }
      }, zoneValues: {this: true});
    });
  }

  void cleanUpTask(SynchronizedTask task) {
    // remove, mark as complete
    tasks.remove(task);
    task.completer.complete();
    cleanUp();
  }

  // implementation
  Future/*<T>*/ synchronized/*<T>*/(computation(), {timeout: null}) {
    // Inner case scenario

    // get status before modifying our task list
    bool locked = this.locked;

    SynchronizedTask previousTask = locked ? tasks.last : null;

    // Create the task and add it to our queue
    SynchronizedTask task = new SynchronizedTask();
    tasks.add(task);

    Future/*<T>*/ run() {
      return _run/*<T>*/(computation).whenComplete(() {
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
        // timeout cleanup
        cleanUpTask(task);
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
