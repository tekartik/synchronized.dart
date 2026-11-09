// ignore_for_file: avoid_print

import 'dart:async';

import 'package:synchronized/global_lock.dart';
import 'package:synchronized/synchronized.dart';

/// One lock shared by all the calls to serialize.
final lock = Lock();
var counter = 0;

/// Read, wait, then write: without the lock, concurrent calls would read the
/// same value and lose increments.
Future<int> increment() => lock.synchronized(() async {
  var value = counter;
  await Future<void>.delayed(const Duration(milliseconds: 1));
  return counter = value + 1;
});

/// A block of a reentrant lock can call synchronized on the same lock.
final reentrantLock = Lock(reentrant: true);

Future<void> addTwice() => reentrantLock.synchronized(() async {
  // With Lock(), this inner call would wait forever (deadlock).
  await reentrantLock.synchronized(() async {
    counter++;
  });
  counter++;
});

Future<void> main() async {
  // Concurrent calls run one after the other.
  await Future.wait([increment(), increment(), increment()]);
  print('counter: $counter'); // 3

  // The value of the block is returned...
  var value = await lock.synchronized(() => 42);
  print('value: $value'); // 42

  // ...and its errors are rethrown, the lock being released.
  try {
    await lock.synchronized(() => throw StateError('failed'));
  } on StateError catch (e) {
    print('error: ${e.message}, locked: ${lock.locked}'); // failed, false
  }

  await addTwice();
  print('counter: $counter'); // 5

  // timeout bounds the wait for the lock: the block never runs.
  var slow = lock.synchronized(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  try {
    await lock.synchronized(() {
      print('never printed');
    }, timeout: const Duration(milliseconds: 10));
  } on TimeoutException {
    print('timeout: lock busy');
  }
  await slow;

  // A GlobalLock excludes the other isolates and processes of the machine
  // (io) or the other tabs of the origin (web). The lock is released when the
  // block completes.
  var globalLock = GlobalLock('synchronized_example');
  await globalLock.synchronized(() async {
    print('holding ${globalLock.name}');
  }, timeout: const Duration(seconds: 30));
}
