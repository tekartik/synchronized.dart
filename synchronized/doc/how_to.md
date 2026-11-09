# Synchronized guide

* [Development notes](synchronized_development.md)
* [README](../README.md): getting started, which lock to use, common mistakes

## Development guide

### basic usage

```dart
var lock = Lock();
// ...
await lock.synchronized(() async {
  // do your stuff
  // await ...
});
```

Have in mind that the `Lock` instance must be shared between calls in order to effectively prevent concurrent execution. For instance, in the example below the lock instance is the same between all `myMethod()` calls.

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

### Turn any object into a lock

Add lock ability to any object.

```dart
import 'package:synchronized/extension.dart';
```

Then you can simply call `synchronized` on any object.

```dart
myObject.synchronized(() async {
  // ...uninterrupted action
});

class MyClass {
  /// Perform a long action that won't be called more than once at a time.
  Future<void> performAction() {
    // Lock at the instance level
    return synchronized(() async {
      // ...uninterrupted action
    });
  }
}
```

Or you can synchronize at the class level

```dart
class MyClass {
  /// Perform a long action that won't be called more than once at a time.
  Future<void> performClassAction() {
    // Lock at the class level
    return runtimeType.synchronized(() async {
      // ...uninterrupted action
    });
  }
}
```

The lock of an object is found by equality (`==`), so two equal objects (two
equal strings for example) share the same lock.
