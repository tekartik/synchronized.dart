import 'package:synchronized/src/utils.dart';
import 'package:synchronized/synchronized.dart';

/// Extension on [Lock] providing synchronous execution when possible, for
/// synchronous [computation]s that don't need to always go through a
/// [Future].
extension TekartikLockExtension on Lock {
  /// Runs the synchronous [computation], returning its result directly (not
  /// wrapped in a [Future]) if this lock can be acquired immediately (see
  /// [Lock.canLock]).
  ///
  /// Otherwise, behaves like [Lock.synchronized]: it waits for the lock to
  /// become available and returns a [Future] that completes with the result
  /// of [computation] once it has run and the lock is released. Because the
  /// return type is [FutureOr], callers that need a consistent `Future<T>`
  /// should `await` the result rather than assume it is always a [Future].
  ///
  /// If [timeout] is specified and the lock is not immediately available,
  /// this waits at most that [Duration] to acquire it; [computation] is
  /// never called and a [TimeoutException] is thrown if the lock cannot be
  /// acquired in time. If [timeout] is `null` (the default), this waits
  /// indefinitely. [timeout] has no effect when the lock is acquired
  /// immediately.
  FutureOr<T> synchronizedSync<T>(
    T Function() computation, {
    Duration? timeout,
  }) {
    if (canLock) {
      return computation();
    }
    return synchronized<T>(() async {
      return computation();
    }, timeout: timeout);
  }
}
