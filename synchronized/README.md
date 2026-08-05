# synchronized

Basic lock mechanism to prevent concurrent access to asynchronous code.

[![pub package](https://img.shields.io/pub/v/synchronized.svg)](https://pub.dev/packages/synchronized)

## Goal

You were missing hard to debug deadlocks, here it is! 

The goal is to propose a solution similar to critical sections and offer a simple `synchronized` API à la Java style.
It provides a basic Lock/Mutex solution to allow features like transactions.

The name is biased as we are single threaded in Dart. However since we write asychronous code (await) like we would
write synchronous code, it makes the overall API feel the same.

The goal is to ensure for a single process (single isolate) that some asynchronous operations can run
without conflict. It won't solve cross-process (or cross-isolate) synchronization.

For single process (single isolate) accessing some resources (database..), it can help to
 * Provide transaction on database system that don't have transaction mechanism (mongodb, file system)
 * In html application make sure some asynchronous UI operation are not conflicting (login, transition)

## Feature

 * By default a lock is not reentrant
 * Timeout support
 * Support for reentrant lock (using Zone)
 * Consistent behavior (i.e. if it is unlocked calling synchronized grab the lock)
 * Values and Errors are properly reported to the caller
 * Work on Browser, DartVM and Flutter
 * No dependencies (other than the sdk itself)
 
It differs from the `pool` package used with a resource count of 1 by supporting a reentrant option

## Usage

A simple usage example:

```dart
import 'package:synchronized/synchronized.dart';

Future<void> main() async {
  // Use this object to prevent concurrent access to data
  var lock = Lock();
  // ...
  await lock.synchronized(() async {
    // Only this block can run (once) until done
    // ...
  });
}
```

If you need a re-entrant lock you can use

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
        
A basic lock is not reentrant by default and does not use Zone. It behaves like an async executor with a pool capacity
of 1

```dart
var lock = Lock();
// ...
lock.synchronized(() async {
  // do some stuff
  // ...
});
```
    
The return value is preserved

```dart
int value = await lock.synchronized(() {
  return 1;
});
```

Using the `package:synchronized/extension.dart` import, you can turn any object into a lock. `synchronized()` can then be called on any
object

```dart
import 'package:synchronized/extension.dart';

class MyClass {

  /// Perform a long action that won't be called more than one at a time.
  Future<void> performAction() {
    // Lock at the instance level
    return synchronized(() async {
      // ...uninterrupted action
    });
  }
}
```
    
## How it works

The next tasks is executed once the previous one is done

Re-entrant locks uses `Zone` to know in which context a block is running in order to be reentrant. It maintains a list
of inner tasks to be awaited for.

## Example

Consider the following dummy code

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

## The Lock instance

Have in mind that the `Lock` instance must be shared between calls in order to effectively prevent concurrent execution. For instance, in the example below the lock instance is the same between all `myMethod()` calls.

```dart
class MyClass {
  final _lock = Lock();

  Future<void> myMethod() async {
    await _lock.synchronized(() async {
      step1();
      step2();
      step3();
    });
  }
}
```

Typically you would create a global or static instance Lock to prevent concurrent access to
a global resource or a class instance Lock to prevent concurrent modifications of
class instance data and resources.

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

With `package:synchronized/extension.dart`, the lock associated with an object
is found by **equality** (`==`/`hashCode`), not by identity, and the cache is
global to the process. Two objects that compare equal therefore share one lock,
which makes value types such as `String` and `int` a namespace shared with
every other library in the application:

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

For reentrant lock, it is true if the lock is not locked or if the current zone lock level is locked by the lock.

For multi lock, it returns true if all inner locks `canLock` values are true.


## MultiLock

As of version 3.3.0, a `MultiLock` is available. It is a lock that can be used to synchronize multiple locks at once.

```dart
var lock1 = Lock();
var lock2 = Lock();
var multiLock = MultiLock(locks: [lock1, lock2]);

multiLock.synchronized(() async {
  // lock1 and lock2 are locked at this point
  ...
});
```

## Features and bugs

Please feel free to: 
* file feature requests and bugs at the [issue tracker][tracker]
* or [contact me][contact_me]
* or visit [tekartik.com](https://www.tekartik.com)
* [How to][how_to] guide


[tracker]: https://github.com/tekartik/synchronized.dart/issues
[contact_me]: https://tekartik-info.web.app/contact
[how_to]: https://github.com/tekartik/synchronized.dart/blob/master/synchronized/doc/how_to.md

