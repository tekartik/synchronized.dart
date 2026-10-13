# Changelog

## 3.5.0

* Fix `ReentrantLock.canLock` reporting the lock free right after a synchronous block while other calls
  were still queued, which let `synchronizedSync` run before earlier `synchronized` calls. In that case
  `canLock` is now `false` and `synchronizedSync` returns a `Future` that completes in order.
* Example: `readme2` was never called and now uses `canLock`

## 3.4.2

* Add `synchronized-lock` agent skill (`skills/`), installable with `dart run skills@ get`

## 3.4.1+2

* Requires dart 3.12
* Improve documentation
* `MultiLock` `timeout` now bounds the whole acquisition (one shared budget) instead of each underlying lock
* `MultiLock` copies its locks at construction
* `synchronizedSync` asserts (in debug mode) when the computation returns a `Future`
* `ReentrantLock.canLock` throws a `StateError` (instead of a `RangeError`, or `true`) when called from a
  zone that outlived its `synchronized` block
* Add `MultiLock.toString`


## 3.4.0+1

* Requires dart 3.11

## 3.4.0

* Requires dart 3.8
* Add `synchronizedSync` for synchronous computation that returns a `FutureOr`

## 3.3.1

* Required dart 3.7

## 3.3.0+3

* Add MultiLock (thanks to @saibotma)

## 3.2.0

* Required dart 3.5

## 3.1.0+1

* Dart 3 support

## 3.0.1

* strict-casts and sdk 2.18 support

## 3.0.0+3

- Add MIT licence

## 3.0.0+2

- `null safety` support, breaking change

## 2.2.0+2

- Add `SynchronizedLock` extension to turn any object into a lock.

## 2.1.1

- pedantic 1.9 support

## 2.1.0+3

- Fix reentrant lock to properly synchronize inner blocks

## 2.0.0

- Remove previously deprecated `SynchronizedLock` and `synchronized` function

## 1.5.2

- Remove dev_test dependency

## 1.5.1

- Dart2 stable support

## 1.5.0

- Deprecate SynchronizedLock and synchronized

## 1.4.0

- Re-use non-reentrant lock in synchronized method

## 1.3.0

- Add non-reentrant lock that do not use Zone

## 1.2.1

- implicit-casts: false (testing dart2 support)

## 1.2.0

- Use generic instead of 2.0 deprecated comments

## 1.1.0

- Fix inner task issue, next outer task will wait for all inner tasks to terminate
- Properly handle nested thrown error

## 1.0.0

- Bump to version 1.0.0

## 0.1.0

- Initial version
