---
name: synchronized-lock
description: >-
  Use when writing Dart or Flutter code with package:synchronized to serialize
  asynchronous work: creating and sharing a Lock, choosing reentrant vs basic
  locks, using timeouts, MultiLock, synchronizedSync, and the extension that
  turns any object into a lock, while avoiding deadlocks and shared-key
  pitfalls.
---

# synchronized: async mutual exclusion in Dart

`package:synchronized` provides a `Lock` whose `synchronized()` method runs a
computation only when no other computation holding the same lock is running.
It is the Dart equivalent of a critical section for `async` code (single
isolate only). It has no dependencies and works on the VM, Flutter and the web.

```dart
import 'package:synchronized/synchronized.dart';

final _lock = Lock();

Future<void> save() => _lock.synchronized(() async {
      // Only one save() body runs at a time.
    });
```

## Guidelines

### Sharing the lock

* Share **one** `Lock` instance between every call site that must be
  serialized. Store it in a `final` instance field, a `static final` field or a
  top-level `final`. Creating a `Lock()` inside the method locks nothing.
* Use an instance-level lock to protect instance state and a static/top-level
  lock to protect a global resource (a file, a database connection, a network
  session).
* A lock only serializes code that goes through `synchronized()` on that lock.
  Code that touches the resource without the lock is not protected.

### Choosing the lock kind

* `Lock()` (default, non-reentrant) is cheap and behaves like an async
  executor with a capacity of 1. Calling `synchronized()` again on the same
  basic lock from inside its own computation **deadlocks**: the inner call
  waits for the outer one, which waits for the inner one.
* `Lock(reentrant: true)` uses a `Zone` to detect nested calls from the same
  computation and lets them proceed. Use it only when nesting is genuinely
  needed (for example a public method that takes the lock and calls another
  public method that also takes it). It is slower than a basic lock.
* Never mix: a computation that acquired a basic lock cannot become reentrant
  by wrapping it later. Decide at construction.
* The package is not a counting semaphore. For "at most N concurrent" use
  `package:pool`; use `synchronized` when N is 1 or when reentrancy is needed.

### Inside the computation

* Always `await` (or return) the `Future` returned by `synchronized()`. The
  computation's return value is the result of that future, and any error thrown
  by the computation is rethrown to the caller, so `try`/`catch` around the
  `await` works as expected.
* Keep the computation short and only cover the critical section. Do not hold
  a lock across user interaction or long polling loops.
* With a reentrant lock, every nested `synchronized()` call must be awaited
  **inside** the enclosing computation. Spawning a nested call and letting it
  outlive its parent block throws a `StateError` ("inner synchronized block
  is spawned outside the block it was started from").
* Do not check `lock.locked` and then call `synchronized()` as an optimization.
  `synchronized()` already runs immediately when the lock is free. `locked`,
  `inLock` and `canLock` are for diagnostics and assertions.
* `inLock` is only meaningful for reentrant locks (is the current zone inside
  this lock?). On a basic lock it just mirrors `locked`; do not rely on it.

### Timeout

* `synchronized(..., timeout: Duration)` bounds **acquiring** the lock, not the
  computation. If the lock is not obtained in time the computation is never
  called and a `TimeoutException` is thrown.
* There is no cancellation. Once a computation has started it always runs to
  completion, even if it takes longer than the timeout that let it start.
* Catch `TimeoutException` from `dart:async` around the `await`.

### Locking on any object (`package:synchronized/extension.dart`)

* Importing `extension.dart` adds `synchronized()` to every `Object`. Inside a
  class, plain `synchronized(() async { ... })` locks on `this`, and
  `runtimeType.synchronized(...)` locks at the class level.
* The lock for an object is found by **equality** (`==`/`hashCode`), not
  identity, in a cache that is global to the process. Two equal objects share
  one lock. Locking on a `String`, an `int` or any value type is a namespace
  shared with every other library in the application.
* When isolation matters, lock on a private `Object()` field or on `this`,
  never on a string key. If you must key by value, wrap the key in a private
  class so nobody else can collide with it.
* The cached lock is dropped when no computation is running or waiting, so
  using many short-lived objects as monitors does not leak.

### MultiLock

* `MultiLock(locks: [a, b])` acquires `a` then `b` in the order given and
  releases them in reverse. Always acquire the same locks in the **same
  relative order** everywhere (in every `MultiLock` and in direct
  `synchronized()` calls) or two callers can deadlock each other.
* `timeout` on a `MultiLock` is one budget for acquiring the whole set, not a
  per-lock timeout.
* The lock list is copied at construction; pass a concrete list, not a lazy
  iterable that rebuilds different `Lock` objects on each iteration.
* `locked`, `inLock` and `canLock` on a `MultiLock` are true only when they are
  true for every member lock.

### synchronizedSync

* `lock.synchronizedSync(() => value)` runs a **synchronous** computation
  without allocating a `Future` when the lock is free, and falls back to
  `synchronized()` (returning a `Future`) when it is not. The return type is
  `FutureOr<T>`; `await` it unless you specifically handle both cases.
* The computation must not return a `Future`. The lock is released as soon as
  the synchronous body returns, so async work would run outside the lock. A
  `Future` result trips an assertion in debug mode. Use `synchronized()` for
  anything asynchronous.

### Scope and limits

* One isolate only. A `Lock` does not synchronize across isolates, processes
  or browser tabs.
* Do not use it to make code "thread safe": Dart is single threaded within an
  isolate. Use it to keep interleaved `await` sequences from stepping on each
  other (read-modify-write on shared state, transaction-like sequences on a
  store without transactions, one-at-a-time UI flows such as login or
  navigation).

## Examples

### Instance lock protecting a read-modify-write sequence

```dart
import 'package:synchronized/synchronized.dart';

class Counter {
  final _lock = Lock();
  int _value = 0;

  Future<int> increment() => _lock.synchronized(() async {
        final current = _value;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        _value = current + 1;
        return _value;
      });
}

Future<void> main() async {
  final counter = Counter();
  await Future.wait(List.generate(10, (_) => counter.increment()));
  // Without the lock this would print a value lower than 10.
  print(await counter.increment()); // 11
}
```

### Global lock guarding a shared resource

```dart
import 'dart:io';
import 'package:synchronized/synchronized.dart';

final _fileLock = Lock();

Future<void> appendLine(File file, String line) => _fileLock.synchronized(() async {
      final content = await file.exists() ? await file.readAsString() : '';
      await file.writeAsString('$content$line\n');
    });
```

### Reentrant lock for nested public methods

```dart
import 'package:synchronized/synchronized.dart';

class Store {
  final _lock = Lock(reentrant: true);
  final _items = <String>[];

  Future<void> add(String item) => _lock.synchronized(() async {
        _items.add(item);
      });

  Future<void> addAll(Iterable<String> items) => _lock.synchronized(() async {
        for (final item in items) {
          // Nested call on the same lock: fine because the lock is reentrant.
          // With Lock() this would deadlock.
          await add(item);
        }
      });
}
```

### Timeout on acquisition

```dart
import 'dart:async';
import 'package:synchronized/synchronized.dart';

Future<bool> tryRefresh(Lock lock) async {
  try {
    await lock.synchronized(() async {
      // refresh...
    }, timeout: const Duration(seconds: 2));
    return true;
  } on TimeoutException {
    // Lock was busy for 2 s; the computation never ran.
    return false;
  }
}
```

### Value and error propagation

```dart
final value = await lock.synchronized(() => 42); // value == 42

try {
  await lock.synchronized(() async {
    throw StateError('boom');
  });
} on StateError {
  // Rethrown to the caller; the lock has already been released.
}
```

### Extension: lock on `this` or on the class

```dart
import 'package:synchronized/extension.dart';

class Session {
  /// At most one login at a time per Session instance.
  Future<void> login() => synchronized(() async {
        // ...
      });

  /// At most one migration at a time across all Session instances.
  Future<void> migrate() => runtimeType.synchronized(() async {
        // ...
      });
}
```

Prefer a private monitor over a value key when other code could use the same
value:

```dart
import 'package:synchronized/extension.dart';

class Cache {
  // Private, so no other library can lock on it by accident.
  final _monitor = Object();

  Future<void> refresh() => _monitor.synchronized(() async {
        // ...
      });
}

// Avoid: any library locking on the string 'cache' shares this lock.
// await 'cache'.synchronized(() async { ... });
```

### MultiLock: acquire several locks atomically

```dart
import 'package:synchronized/synchronized.dart';

final accountsLock = Lock();
final ledgerLock = Lock();

// Same order everywhere that both locks are needed.
final transferLock = MultiLock(locks: [accountsLock, ledgerLock]);

Future<void> transfer() => transferLock.synchronized(() async {
      // accountsLock and ledgerLock are both held here.
    });
```

### synchronizedSync: fast path for synchronous bodies

```dart
import 'package:synchronized/synchronized.dart';

final _lock = Lock();
final _seen = <String>{};

/// Returns synchronously when the lock is free, otherwise waits.
Future<bool> markSeen(String id) async => await _lock.synchronizedSync(() {
      return _seen.add(id); // synchronous body only
    });
```

### Testing that calls are serialized

```dart
import 'package:synchronized/synchronized.dart';
import 'package:test/test.dart';

void main() {
  test('synchronized serializes work', () async {
    final lock = Lock();
    final log = <String>[];
    Future<void> job(String name) => lock.synchronized(() async {
          log.add('$name start');
          await Future<void>.delayed(const Duration(milliseconds: 1));
          log.add('$name end');
        });
    await Future.wait([job('a'), job('b')]);
    expect(log, ['a start', 'a end', 'b start', 'b end']);
  });
}
```
