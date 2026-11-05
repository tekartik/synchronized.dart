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
///   macOS) or the system temp folder (elsewhere), touched every second by
///   its holder; a waiter takes it over once it was not touched for 10
///   seconds, so a holder that died (crash, kill, killed isolate) blocks the
///   others for 10 seconds at most. A holder whose event loop is frozen
///   longer (debugger pause, long synchronous work) may lose it. The
///   heartbeat keeps the isolate alive until [GlobalLockHandle.release].
/// * web: across the tabs and workers of the same origin, using the Web Locks
///   API (`navigator.locks`); the browser releases it when the tab closes.
/// * elsewhere (no Web Locks API): within the current isolate only.
///
/// Not reentrant: acquiring it again while holding it waits for itself
/// (until the timeout, if any).
abstract class GlobalLock {
  /// Creates a lock named [name].
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
