# synchronized

Lock mechanism to prevent concurrent access to asynchronous code: a `Lock` runs
one `synchronized` block at a time, like a critical section for code that uses
`await`.

[![pub package](https://img.shields.io/pub/v/synchronized.svg)](https://pub.dev/packages/synchronized)

## Getting started

Add the dependency:

```sh
dart pub add synchronized
```

Share one `Lock` between all the calls that must not run at the same time:

```dart
import 'package:synchronized/synchronized.dart';

final lock = Lock();
var counter = 0;

Future<int> increment() => lock.synchronized(() async {
  // Only one block of this lock runs at a time, the others wait.
  var value = counter;
  await Future<void>.delayed(const Duration(milliseconds: 1));
  return counter = value + 1;
});

Future<void> main() async {
  await Future.wait([increment(), increment(), increment()]);
  print(counter); // 3 (1 without the lock)
}
```

`synchronized` returns the value of the block and rethrows its errors.

### Which lock to use

| Lock                         | Use it to                                                 | Import              |
|------------------------------|-----------------------------------------------------------|---------------------|
| `Lock()`                     | serialize async code in one isolate (not reentrant)       | `synchronized.dart` |
| `Lock(reentrant: true)`      | same, when a block calls `synchronized` on the same lock  | `synchronized.dart` |
| `MultiLock(locks: [a, b])`   | hold several locks at once                                | `synchronized.dart` |
| `anyObject.synchronized(..)` | lock on an object without a `Lock` field                  | `extension.dart`    |
| `GlobalLock('name')`         | exclude other isolates, processes or browser tabs         | `global_lock.dart`  |

All of them work on every platform: Dart VM, Flutter (mobile, desktop and web),
browser (dart2js and dart2wasm) and node. What a `GlobalLock` excludes depends
on the platform:

* io (Dart VM, Flutter mobile and desktop): the isolates and processes of the
  machine run by the same user.
* web (browser, Flutter web): the tabs and workers of the same origin (Web Locks
  API, available on https and localhost pages).
* node: the current process only.
* elsewhere (no Web Locks API, such as a page served over plain http): the
  current isolate only.

`BasicLock` and `ReentrantLock` are the classes behind `Lock()` and
`Lock(reentrant: true)`. They are not exported: create locks with `Lock()`.

### Common mistakes

* Calling `synchronized` on a `Lock()` from inside one of its own blocks never
  completes (deadlock, no error). Use `Lock(reentrant: true)`, or move the
  inner code to a private method that does not take the lock.
* Creating the `Lock` inside the method: each call gets its own lock and
  nothing is serialized. Keep it in a `final` field or a top-level variable.
* Not awaiting (or returning) the future of `synchronized`: its errors are then
  unhandled.
* `timeout` bounds the wait for the lock, not the block. When it expires a
  `TimeoutException` (`dart:async`) is thrown and the block never runs. A block
  that started is never cancelled.
* A `Lock` does not cross isolates, processes or tabs: use a `GlobalLock`.
* `GlobalLock` has no `close()`. Use `GlobalLock.synchronized`, which releases
  the lock for you, or call `release()` on the handle returned by `acquire()`
  in a `finally`. It is not reentrant either.
* With the extension, locking on a `String` (or any value) shares the lock with
  all the code that locks on an equal value.

## Features

* An async version of the Java `synchronized` keyword. Dart runs one isolate on
  one thread, but code that awaits can interleave: a lock keeps a sequence of
  awaits (read, modify, write; a login flow; a transaction on a store without
  transactions) from running while another one is in progress.
* Not reentrant by default, reentrant option (using `Zone`).
* Timeout support.
* Values and errors are returned to the caller.
* Consistent behavior: when the lock is free, the block starts at once.
* `GlobalLock` across isolates, processes and browser tabs.
* No dependencies (other than the SDK).

It differs from the `pool` package used with a resource count of 1 by its
reentrant option.

## How it works

The next block runs once the previous one is done.

Consider the following code:

```dart
Future<void> writeSlow(int value) async {
  await Future<void>.delayed(const Duration(milliseconds: 1));
  stdout.write(value);
}

Future<void> write(List<int> values) async {
  for (var value in values) {
    await writeSlow(value);
  }
}

Future<void> write1234() async {
  await write([1, 2, 3, 4]);
}
```

Doing

```dart
write1234();
write1234();
```

would print

    11223344

while doing

```dart
lock.synchronized(write1234);
lock.synchronized(write1234);
```

would print

    12341234

A reentrant lock uses a `Zone` to know whether a block runs inside one of its
own blocks. It keeps a list of inner tasks to wait for.

## The Lock instance

The `Lock` instance must be shared between calls in order to prevent concurrent
execution. In the example below, the lock is the same for all the
`myMethod()` calls of an instance.

```dart
class MyClass {
  final _lock = Lock();

  Future<void> myMethod() async {
    await _lock.synchronized(() async {
      await step1();
      await step2();
      await step3();
    });
  }
}
```

Use a global or static lock to protect a global resource, and an instance lock
to protect the data and resources of an instance.

## Reentrant lock

A block of a reentrant lock can call `synchronized` again on the same lock:

```dart
var lock = Lock(reentrant: true);
// ...
await lock.synchronized(() async {
  // do some stuff
  // ...

  await lock.synchronized(() async {
    // other stuff
  });
});
```

With `Lock()`, the inner call would wait for the outer block, which waits for
the inner call: a deadlock. With a reentrant lock, await every inner call
inside the block that started it, otherwise it throws a `StateError`.

## Timeout

`synchronized()` accepts an optional `timeout`:

```dart
try {
  await lock.synchronized(() async {
    // ...
  }, timeout: const Duration(seconds: 1));
} on TimeoutException catch (_) {
  // The lock could not be acquired in time.
}
```

The timeout bounds **acquiring** the lock, not running the computation. If it
expires, the computation is never called and a `TimeoutException` is thrown.
Once the computation has started it runs to completion: there is no
cancellation, so a computation may well outlive the timeout that let it start.

For a `MultiLock` the timeout is the budget for acquiring the whole set, not
for each member lock in turn.

## Locking on any object

With `package:synchronized/extension.dart`, `synchronized()` can be called on
any object:

```dart
import 'package:synchronized/extension.dart';

class MyClass {
  /// Perform a long action that won't be called more than once at a time.
  Future<void> performAction() {
    // Lock at the instance level
    return synchronized(() async {
      // ...uninterrupted action
    });
  }

  /// Same, across all the instances of the class.
  Future<void> performClassAction() {
    // Lock at the class level
    return runtimeType.synchronized(() async {
      // ...uninterrupted action
    });
  }
}
```

The lock associated with an object is found by **equality** (`==`/`hashCode`),
not by identity, and the cache is global to the process. Two objects that
compare equal therefore share one lock, which makes value types such as
`String` and `int` a namespace shared with every other library in the
application:

```dart
// These contend with each other, and with any other library
// that happens to lock on the same text.
await 'my-key'.synchronized(() async { /* ... */ });
```

When you want isolation, lock on a private instance instead:

```dart
class MyClass {
  final _lock = Object();

  Future<void> myMethod() => _lock.synchronized(() async {
    // ...
  });
}
```

## locked/inLock/canLock status

### locked

For basic and reentrant lock, `locked` returns whether the lock is currently locked.

For multi lock, it returns true if all inner locks `locked` values are true.

### inLock

For reentrant locks, `inLock` returns whether the current zone is locked by the lock.
i.e. it is true if the current block is running inside a `synchronized` block of the lock.

For basic lock, it matches the `locked` property and since it does not mean anything,
it should not be used as behavior may change in the future.

For multi lock, it returns true if all inner locks `inLock` values are true.

### canLock

canLock returns whether the lock can be locked immediately.

For basic lock, it is true if the lock is not locked.

For reentrant lock, it is true if the current zone lock level is free: outside of the lock, it can be false
right after a block completed while other calls are still queued, even if `locked` is already false.

For multi lock, it returns true if all inner locks `canLock` values are true.

There is no need to check `locked` or `canLock` before calling `synchronized`:
when the lock is free, the block starts at once.

## MultiLock

As of version 3.3.0, a `MultiLock` is available. It is a lock that can be used to synchronize multiple locks at once.

```dart
var lock1 = Lock();
var lock2 = Lock();
var multiLock = MultiLock(locks: [lock1, lock2]);

await multiLock.synchronized(() async {
  // lock1 and lock2 are locked at this point
  // ...
});
```

The locks are acquired in the order given and released in reverse order. Use
the same order everywhere the same locks are taken together, otherwise two
callers can deadlock each other.

## GlobalLock (across isolates, processes and tabs)

As of version 3.6.0, `package:synchronized/global_lock.dart` provides a `GlobalLock`, identified by a
name, that two isolates, two processes or two browser tabs cannot hold at the same time:

```dart
import 'package:synchronized/global_lock.dart';

final lock = GlobalLock('my_app_firebase_emulator');

Future<void> useTheEmulator() async {
  await lock.synchronized(() async {
    // Only one isolate or process of the machine runs this at a time.
  }, timeout: const Duration(minutes: 10));
}

// Or hold it across calls.
Future<void> holdAcrossCalls() async {
  var handle = await lock.acquire(timeout: const Duration(minutes: 10));
  try {
    // ...
  } finally {
    await handle.release();
  }
}
```

* The name is any string, the same for all the users of the lock. Pick a name
  specific to your application and resource.
* `timeout` bounds the wait as for a `Lock`, a `TimeoutException` is thrown
  when it expires (`Duration.zero` tries once). Without a timeout, `acquire`
  waits as long as another program holds the lock.
* `release()` can be called more than once, later calls do nothing.
* It is not reentrant: acquiring it again while holding it waits for itself
  (until the timeout, if any).

Platforms:

* io (Dart VM, Flutter mobile and desktop): shared by all the isolates and processes of the machine
  run by the same user. The lock is a file created exclusively in `/tmp/synchronized_global_lock_<user>`
  (Linux, macOS, whatever `TMPDIR`) or in the system temp folder (Windows, mobile), touched every second
  by a heartbeat isolate: the lock stays held while the event loop of the holder is blocked (synchronous
  work), and is released at once when the holder isolate exits without releasing it. A waiter takes over
  a file it saw untouched for 10 seconds (timed on its own clock, so a clock change or a suspended machine
  never breaks a live lock), so a holder process that died (crash, kill) blocks the others for about 10
  seconds, and nothing outside this folder can hold the lock.
* web: shared by the tabs and workers of the same origin, using the
  [Web Locks API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Locks_API); released when the
  tab closes.
* node (its Web Locks API, node 24+): within the current process only (and its worker threads), not across
  processes.
* elsewhere (no Web Locks API, such as a page served over plain http): within the current isolate only.

It has no dependencies.

## Features and bugs

Please feel free to: 
* file feature requests and bugs at the [issue tracker][tracker]
* or [contact me][contact_me]
* or visit [tekartik.com](https://tekartik.com/)
* [How to][how_to] guide


[tracker]: https://github.com/tekartik/synchronized.dart/issues
[contact_me]: https://tekartik.com/contact/
[how_to]: https://github.com/tekartik/synchronized.dart/blob/master/synchronized/doc/how_to.md
