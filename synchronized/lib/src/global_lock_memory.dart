import 'dart:async';

import 'basic_lock.dart';
import 'global_lock.dart';

/// The locks of this isolate, by name.
final _locks = <String, BasicLock>{};

/// A [GlobalLock] within the current isolate only (no shared lock available
/// on this platform).
GlobalLock newGlobalLock(String name) => GlobalLockMemory(name);

/// A [GlobalLock] within the current isolate only.
class GlobalLockMemory with GlobalLockMixin {
  /// Creates the lock [name] of this isolate.
  GlobalLockMemory(this.name);

  @override
  final String name;

  @override
  Future<GlobalLockHandle> acquire({Duration? timeout}) {
    final lock = _locks[name] ??= BasicLock();
    final acquired = Completer<GlobalLockHandle>();
    final released = Completer<void>();
    unawaited(
      lock
          .synchronized(() {
            acquired.complete(_GlobalLockMemoryHandle(released));
            return released.future;
          }, timeout: timeout)
          .catchError((Object error, StackTrace stackTrace) {
            if (!acquired.isCompleted) {
              acquired.completeError(
                error is TimeoutException
                    ? globalLockTimeoutException(name, timeout)
                    : error,
                stackTrace,
              );
            }
          }),
    );
    return acquired.future;
  }
}

class _GlobalLockMemoryHandle implements GlobalLockHandle {
  _GlobalLockMemoryHandle(this._released);

  final Completer<void> _released;

  @override
  Future<void> release() async {
    if (!_released.isCompleted) {
      _released.complete();
    }
  }
}
