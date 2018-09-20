# Synchronized guide

* [Development notes](synchronized_development.md)

## Development guide

### basic usage

```dart
var lock = new Lock();
// ...
await lock.synchronized(() async {
  // do you stuff
  // await ...
});
```

Have in mind that the `Lock` instance must be shared between calls in order to effectively prevent concurrent execution. For instance, in the example below the lock instance is the same between all `myMethod()` calls.

```
class MyClass {
  Lock _lock = new Lock();

  Future<void> myMethod() async {
    await _lock.synchronized(() async {
      step1();
      step2();
      step3();
    });
  }
}
```
