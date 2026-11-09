import 'dart:async';

import 'global_lock_memory.dart'
    if (dart.library.io) 'global_lock_io.dart'
    if (dart.library.js_interop) 'global_lock_web.dart'
    as impl;

/// A lock shared beyond the current isolate, identified by its [name].
///
/// Two [GlobalLock] objects with the same [name] exclude each other:
/// * io (Dart VM, Flutter mobile and desktop): across all the isolates and
///   processes of the machine run by the same user. The lock is a file
///   created exclusively in `/tmp/synchronized_global_lock_<user>` (Linux,
///   macOS) or the system temp folder (elsewhere), touched every second by a
///   heartbeat isolate, so the lock stays held while the event loop of the
///   holder is blocked (synchronous work). The lock is released at once when
///   the holder isolate exits without releasing it; a waiter takes over a
///   file it saw untouched for 10 seconds (timed on its own clock, so a clock
///   change or a suspended machine never breaks a live lock), so a holder
///   process that died (crash, kill) blocks the others for about 10 seconds.
/// * web: across the tabs and workers of the same origin, using the Web Locks
///   API (`navigator.locks`); the browser releases it when the tab closes.
/// * node (its Web Locks API, node 24+): within the current process only
///   (and its worker threads), not across processes.
/// * elsewhere (no Web Locks API): within the current isolate only.
///
/// Not reentrant: acquiring it again while holding it waits for itself
/// (until the timeout, if any).
///
/// ```dart
/// final lock = GlobalLock('my_app_firebase_emulator');
///
/// // Released when the computation completes.
/// await lock.synchronized(() async {
///   // ...
/// }, timeout: const Duration(minutes: 10));
///
/// // Or held across calls: always release the handle.
/// var handle = await lock.acquire(timeout: const Duration(minutes: 10));
/// try {
///   // ...
/// } finally {
///   await handle.release();
/// }
/// ```
///
/// There is nothing to close: a lock that is not held uses no resource.
abstract class GlobalLock {
  /// Creates a lock named [name].
  ///
  /// [name] is any string, the same for all the users of the lock: pick one
  /// specific to the application and the resource it protects. Creating the
  /// object does not acquire the lock.
  factory GlobalLock(String name) => impl.newGlobalLock(name);

  /// The lock name, the same for all the users of the lock.
  String get name;

  /// Waits for the lock and holds it until [GlobalLockHandle.release].
  ///
  /// If [timeout] is specified, this waits at most that [Duration] and throws
  /// a [TimeoutException] if the lock could not be acquired in time
  /// ([Duration.zero] tries once). If [timeout] is `null` (the default), this
  /// waits indefinitely.
  Future<GlobalLockHandle> acquire({Duration? timeout});

  /// Runs [computation] holding the lock, released when it completes.
  ///
  /// [timeout] bounds the wait for the lock as in [acquire], [computation] is
  /// then never called. Returns the value of [computation] and rethrows its
  /// errors.
  Future<T> synchronized<T>(
    FutureOr<T> Function() computation, {
    Duration? timeout,
  });
}

/// A held [GlobalLock], see [GlobalLock.acquire].
///
/// Call [release] (in a `finally`) when done: until then the other users of
/// the lock wait. A handle never released holds the lock until the holder
/// isolate exits (io) or the tab closes (web).
abstract class GlobalLockHandle {
  /// Releases the lock (once, later calls do nothing).
  Future<void> release();
}

/// [GlobalLock.synchronized] on top of [GlobalLock.acquire].
mixin GlobalLockMixin implements GlobalLock {
  @override
  Future<T> synchronized<T>(
    FutureOr<T> Function() computation, {
    Duration? timeout,
  }) async {
    final handle = await acquire(timeout: timeout);
    try {
      return await computation();
    } finally {
      await handle.release();
    }
  }

  @override
  String toString() => 'GlobalLock($name)';
}

/// The [TimeoutException] thrown when the lock [name] was not acquired within
/// [timeout], [details] (the last error) appended.
TimeoutException globalLockTimeoutException(
  String name,
  Duration? timeout, {
  String? details,
}) => TimeoutException(
  'GlobalLock($name) not acquired${details == null ? '' : ', $details'}',
  timeout,
);
