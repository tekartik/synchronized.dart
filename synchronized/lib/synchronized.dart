// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// This simulates the synchronized feature of Java in an async way.
///
/// Create a shared [Lock] object and use it using the [Lock.synchronized]
/// method to prevent concurrent access to a shared resource.
///
/// ```dart
/// class MyClass {
///   final _lock = Lock();
///
///   Future<void> myMethod() async {
///     await _lock.synchronized(() async {
///       await step1();
///       await step2();
///       await step3();
///     });
///   }
/// }
/// ```
///
/// Which lock to use:
/// * `Lock()`: one block at a time within the isolate, not reentrant (a block
///   calling [Lock.synchronized] again on the same lock deadlocks).
/// * `Lock(reentrant: true)`: same, a block can call [Lock.synchronized] again
///   on the same lock.
/// * [MultiLock]: holds several locks at once.
/// * `package:synchronized/extension.dart`: `synchronized` on any object.
/// * `package:synchronized/global_lock.dart`: a `GlobalLock` excludes the other
///   isolates and processes of the machine (io) or the other tabs of the
///   origin (web).
library;

import 'dart:async';

import 'package:synchronized/src/basic_lock.dart';
import 'package:synchronized/src/reentrant_lock.dart';

export 'src/lock_extension.dart' show TekartikLockExtension;
export 'src/multi_lock.dart' show MultiLock;

/// A mutual-exclusion lock: serializes access to a shared resource across
/// asynchronous code, similar to Java's `synchronized`.
///
/// A [Lock] can be reentrant (backed by a [Zone], see the [Lock.new]
/// `reentrant` parameter) or non-reentrant, in which case it behaves like an
/// asynchronous executor with a capacity of 1 (only one call to
/// [synchronized] runs at a time; a nested call from within an already-held
/// non-reentrant lock deadlocks).
///
/// Share one instance (a `final` field or a top-level variable) between all
/// the calls to serialize: a [Lock] created in each call locks nothing.
///
/// ```dart
/// final lock = Lock();
///
/// Future<int> next() => lock.synchronized(() async {
///   // Only one block of this lock runs at a time, the others wait.
///   return await readAndIncrementCounter();
/// });
/// ```
///
/// A [Lock] works within one isolate. Use a `GlobalLock`
/// (`package:synchronized/global_lock.dart`) across isolates, processes or
/// browser tabs.
abstract class Lock {
  /// Creates a [Lock].
  ///
  /// If [reentrant] is `true` (defaults to `false`), the returned lock uses a
  /// [Zone] to detect when [synchronized] is called again from within a
  /// computation that already holds the same lock, and lets that nested call
  /// proceed instead of deadlocking. Non-reentrant locks are cheaper but will
  /// deadlock on such nested calls.
  factory Lock({bool reentrant = false}) {
    if (reentrant) {
      return ReentrantLock();
    } else {
      return BasicLock();
    }
  }

  /// Runs [computation] once this lock is available, preventing any other
  /// call to [synchronized] on this lock from running concurrently.
  ///
  /// If [timeout] is specified, this waits at most that [Duration] to
  /// acquire the lock; [computation] is never called and a [TimeoutException]
  /// is thrown if the lock cannot be acquired in time. If [timeout] is
  /// `null` (the default), this waits indefinitely.
  ///
  /// Returns a [Future] that completes with the value returned by
  /// [computation] (or its awaited result, if it returns a [Future]) once
  /// [computation] finishes and the lock is released. Any error thrown by
  /// [computation] is rethrown through the returned [Future].
  ///
  /// When the lock is free, [computation] starts at once. There is no
  /// cancellation: once started, [computation] runs to completion, even past
  /// [timeout].
  Future<T> synchronized<T>(
    FutureOr<T> Function() computation, {
    Duration? timeout,
  });

  /// Whether the lock is currently held, i.e. a call to [synchronized] is
  /// currently running (or waiting for a nested [synchronized] call to
  /// finish, for a reentrant lock).
  bool get locked;

  /// For a reentrant lock, whether the current [Zone] is nested inside a
  /// [synchronized] call on this lock (so a further nested call would not
  /// deadlock).
  ///
  /// For a non-reentrant lock this simply returns [locked]; that value does
  /// not indicate reentrancy and should not be relied upon, as it may change
  /// in the future.
  bool get inLock;

  /// Whether calling [synchronized] right now would be able to acquire the
  /// lock without waiting.
  ///
  /// For a basic (non-reentrant) lock, this is the same as `!`[locked]. For a
  /// reentrant lock, this is whether the current nesting level is free (the
  /// first level outside of the lock's own zone); it can be `false` while
  /// [locked] is already `false`, when a block just completed and other
  /// calls are queued behind it. For a [MultiLock], this is `true` only when
  /// every underlying lock can be acquired.
  bool get canLock;
}
