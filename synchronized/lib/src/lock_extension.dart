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
  ///
  /// [computation] must be synchronous. The lock is only held while
  /// [computation] itself runs, so a [computation] that returns a [Future]
  /// would let that future complete outside the lock, silently losing mutual
  /// exclusion. Returning a [Future] therefore trips an assertion in debug
  /// mode; use [Lock.synchronized] for asynchronous work.
  FutureOr<T> synchronizedSync<T>(
    T Function() computation, {
    Duration? timeout,
  }) {
    T compute() {
      var result = computation();
      assert(result is! Future, _asyncComputationMessage);
      return result;
    }

    if (canLock) {
      return compute();
    }
    return synchronized<T>(() async {
      return compute();
    }, timeout: timeout);
  }
}

const _asyncComputationMessage =
    'synchronizedSync() requires a synchronous computation: the lock is '
    'released as soon as it returns, so a Future result would complete '
    'outside the lock. Use synchronized() instead.';
