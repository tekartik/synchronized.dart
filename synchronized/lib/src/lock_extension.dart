import 'package:synchronized/src/utils.dart';
import 'package:synchronized/synchronized.dart';

/// Extension on [Lock] to provide synchronous execution when possible
extension TekartikLockExtension on Lock {
  /// Executes a synchronous [computation].
  /// If the lock is not locked, it will run the computation immediately and
  /// return its value synchronously.
  ///
  /// Otherwise, it will wait for the lock to be available and return the
  /// Future value of the computation.
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
