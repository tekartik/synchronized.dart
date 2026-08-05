import 'dart:async';

import 'package:synchronized/src/extension_impl.dart' as impl;

/// Add lock ability to any object.
///
/// Then you can simple call on any object.
///
/// ```dart
/// myObject.synchronized(() async {
///   // ...uninterrupted action
/// });
///
/// class MyClass {
///   /// Perform a long action that won't be called more than once at a time.
///   Future<void> performAction() {
///     // Lock at the instance level
///     return synchronized(() async {
///       // ...uninterrupted action
///     });
///   }
/// }
/// ```
/// Or you can synchronize at the class level
///
/// ```dart
/// class MyClass {
///   /// Perform a long action that won't be called more than once at a time.
///   Future<void> performClassAction() {
///     // Lock at the class level
///     return runtimeType.synchronized(() async {
///       // ...uninterrupted action
///     });
///   }
/// }
/// ```
///
/// The lock mechanism is based on equality (`==`/`hashCode`), not identity, so
/// any two objects that compare equal share the same lock. Beware of potential
/// conflicts: the lock cache is global to the process, so value types such as
/// `String` or `int` are effectively a namespace shared with every other
/// library in the application. Lock on a private instance
/// (`final _lock = Object();`) when isolation matters.
extension SynchronizedLock on Object {
  /// Runs [computation] once this object's implicit lock is available,
  /// preventing any other call to [synchronized] on an equal object
  /// (compared with `==`) from running concurrently.
  ///
  /// If [timeout] is specified, this waits at most that [Duration] to
  /// acquire the lock; [computation] is never called and a
  /// [TimeoutException] is thrown if the lock cannot be acquired in time. If
  /// [timeout] is `null` (the default), this waits indefinitely.
  ///
  /// Returns a [Future] that completes with the value returned by
  /// [computation] (or its awaited result, if it returns a [Future]) once
  /// [computation] finishes and the lock is released. Any error thrown by
  /// [computation] is rethrown through the returned [Future].
  Future<T> synchronized<T>(
    FutureOr<T> Function() computation, {
    Duration? timeout,
  }) {
    return impl.objectSynchronized<T>(this, computation, timeout: timeout);
  }
}
