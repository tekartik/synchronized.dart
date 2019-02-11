import 'package:synchronized/synchronized.dart' as synchronized_lib;

import 'utils.dart';

// A [SynchronizedTask] only complete when all precedent task complete
// i.e. in case of timeout
class SynchronizedTask {
  Completer completer = Completer.sync();

  // Inner task, a task won't be marked as complete until all
  // its inner task are complete
  List<Future> innerFutures;

  // Add inner task if any
  void addInnerFuture(Future future) {
    if (innerFutures == null) {
      innerFutures = [];
    }
    innerFutures.add(future);
    // Make sure we catch the error to prevent test error
    future.catchError((e) {}).whenComplete(() {
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
        } else {
          return null;
        }
      });

  @override
  String toString() => "SynchronizedTask[${identityHashCode(this)}]";
}

// You can define synchonized lock object directly
// for convenient access
class ReentrantLock implements synchronized_lib.Lock {
  final List<SynchronizedTask> tasks = [];

  // implementation when running
  Future<T> _createAndRunTask<T>(FutureOr<T> computation(),
      {Duration timeout}) {
    // Inner case scenario

    // get status before modifying our task list
    bool locked = this.locked;

    SynchronizedTask previousTask = locked ? tasks.last : null;

    // Create the task and add it to our queue
    SynchronizedTask task = SynchronizedTask();
    tasks.add(task);

    Future<T> run() {
      return _runTask<T>(task, computation).whenComplete(() {
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

  // testing only
  Future get ready {
    if (!locked) {
      return Future.value();
    }
    return tasks.last.future;
  }

  void removeTask(SynchronizedTask task) {
    tasks.remove(task);
  }

  void cleanUpTask(SynchronizedTask task) {
    void _cleanUp() {
      removeTask(task);
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

  // return true if the block is currently locked
  @override
  bool get locked => tasks.isNotEmpty || inZone;

  Future<T> _runTask<T>(SynchronizedTask task, FutureOr<T> computation()) {
    return Future.sync(() {
      return runZoned(() {
        if (computation != null) {
          return computation();
        } else {
          return null;
        }
      }, zoneValues: {this: task});
    });
  }

  // implementation
  @override
  Future<T> synchronized<T>(FutureOr<T> computation(), {Duration timeout}) {
    // Inner case scenario

    // If currently in a zone,
    // execute right away
    SynchronizedTask inZoneTask = Zone.current[this] as SynchronizedTask;
    if (inZoneTask != null) {
      var result;
      if (computation != null) {
        try {
          result = computation();
        } catch (e) {
          // Catch direct error right away
          return Future.error(e);
        }
        // If it is a future add it to the task
        if (result is Future) {
          inZoneTask.addInnerFuture(result);
          return result as Future<T>;
        }
      }
      // Non future block handling
      return Future.value(result as FutureOr<T>);
    }

    return _createAndRunTask(computation, timeout: timeout);
  }

  @override
  String toString() => 'ReentrantLock[${identityHashCode(this)}]';

  bool get inZone => (Zone.current[this] != null);

  @override
  bool get inLock => inZone;
}
