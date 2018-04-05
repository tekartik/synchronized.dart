# Synchronized guide

* [Development notes](synchronized_development.md)

## Development guide

### basic usage

```dart
var lock = new Lock();
await lock.synchronized(() async {
  // do you stuff
  // await ...
});
```
