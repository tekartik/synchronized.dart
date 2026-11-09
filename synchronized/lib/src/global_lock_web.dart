import 'dart:async';
import 'dart:js_interop';

import 'global_lock.dart';
import 'global_lock_memory.dart';

@JS('navigator')
external _Navigator? get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external _LockManager? get locks;
}

extension type _LockManager._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> request(
    String name,
    _LockOptions options,
    JSFunction callback,
  );
}

extension type _LockOptions._(JSObject _) implements JSObject {
  external factory _LockOptions({_AbortSignal? signal, bool? ifAvailable});
}

@JS('AbortSignal')
extension type _AbortSignal._(JSObject _) implements JSObject {
  external static _AbortSignal timeout(int milliseconds);

  external bool get aborted;
}

/// The prefix of the Web Locks name of a lock whose name starts with `-`
/// (names reserved by the Web Locks API, which rejects their requests).
const _reservedNamePrefix = 'synchronized_global_lock:';

/// The Web Locks name of the [GlobalLock] [name]: [name] itself, so that it
/// stays the same across tabs and versions, unless it starts with `-`
/// (rejected by the Web Locks API): then [name] prefixed with
/// `synchronized_global_lock:` (reversible: remove the prefix when followed
/// by `-`).
String globalLockWebLockName(String name) =>
    name.startsWith('-') ? '$_reservedNamePrefix$name' : name;

/// A [GlobalLock] shared by the tabs and workers of the origin (Web Locks
/// API), within the current isolate only when the API is missing (node
/// before 24, insecure context).
GlobalLock newGlobalLock(String name) {
  final locks = _navigator?.locks;
  if (locks == null) {
    return GlobalLockMemory(name);
  }
  return _GlobalLockWeb(name, locks);
}

/// A [GlobalLock] held with `navigator.locks.request`.
class _GlobalLockWeb with GlobalLockMixin {
  _GlobalLockWeb(this.name, this._locks);

  @override
  final String name;

  final _LockManager _locks;

  @override
  Future<GlobalLockHandle> acquire({Duration? timeout}) async {
    final granted = Completer<void>();
    final released = Completer<void>();

    // Called once granted (or with null when not available for an
    // ifAvailable request), the lock is held until the returned promise
    // completes.
    JSPromise<JSAny?>? callback(JSAny? lock) {
      if (lock == null) {
        granted.completeError(globalLockTimeoutException(name, timeout));
        return null;
      }
      granted.complete();
      return released.future.toJS;
    }

    final _AbortSignal? signal;
    final _LockOptions options;
    if (timeout == null) {
      signal = null;
      options = _LockOptions();
    } else if (timeout <= Duration.zero) {
      signal = null;
      options = _LockOptions(ifAvailable: true);
    } else {
      signal = _AbortSignal.timeout(timeout.inMilliseconds);
      options = _LockOptions(signal: signal);
    }
    final request = _locks
        .request(globalLockWebLockName(name), options, callback.toJS)
        .toDart;
    unawaited(
      request.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (!granted.isCompleted) {
            // Aborted by the timeout before being granted; any other
            // rejection (invalid request, insecure context) as is.
            if (signal?.aborted ?? false) {
              granted.completeError(globalLockTimeoutException(name, timeout));
            } else {
              granted.completeError(error, stackTrace);
            }
          }
        },
      ),
    );
    await granted.future;
    return _GlobalLockWebHandle(released, request);
  }
}

class _GlobalLockWebHandle implements GlobalLockHandle {
  _GlobalLockWebHandle(this._released, this._request);

  final Completer<void> _released;
  final Future<void> _request;

  @override
  Future<void> release() async {
    if (!_released.isCompleted) {
      _released.complete();
    }
    try {
      await _request;
    } catch (_) {}
  }
}
