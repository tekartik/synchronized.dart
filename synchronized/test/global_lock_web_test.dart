@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:synchronized/global_lock.dart';
import 'package:synchronized/src/global_lock_memory.dart';
import 'package:synchronized/src/global_lock_web.dart';
import 'package:test/test.dart';

import 'src/global_lock_test_utils.dart';

@JS('Promise')
extension type _Promise._(JSObject _) implements JSObject {
  external static JSPromise<JSAny?> reject(JSAny? reason);
}

@JS('Error')
extension type _JSError._(JSObject _) implements JSObject {
  external factory _JSError(String message);
}

/// `navigator.locks`.
JSObject get _locks =>
    (globalContext['navigator'] as JSObject)['locks'] as JSObject;

void main() {
  test('GlobalLock uses the Web Locks API', () {
    // Not the fallback within the current isolate.
    expect(GlobalLock('test'), isNot(isA<GlobalLockMemory>()));
  });

  test('Web Locks name', () {
    // Unchanged, the same across tabs and versions.
    for (var name in ['test', 'a-b', '', ' -', 'é']) {
      expect(globalLockWebLockName(name), name);
    }
    // Rejected by the Web Locks API, prefixed.
    expect(globalLockWebLockName('-a'), 'synchronized_global_lock:-a');
    expect(globalLockWebLockName('-'), 'synchronized_global_lock:-');
  });

  test('same Web Lock as a raw request', () async {
    var name = newGlobalLockName();
    var granted = Completer<void>();
    var release = Completer<void>();
    var request = _locks.callMethod<JSPromise<JSAny?>>(
      'request'.toJS,
      name.toJS,
      ((JSAny? lock) {
        granted.complete();
        return release.future.toJS;
      }).toJS,
    );
    await granted.future;
    await expectLater(
      GlobalLock(name).acquire(timeout: Duration.zero),
      throwsA(isA<TimeoutException>()),
    );
    release.complete();
    await request.toDart;
    await (await GlobalLock(name).acquire()).release();
  });

  test('rejected request: real error, not a timeout', () async {
    // A request rejected for another reason than the timeout.
    _locks['request'] =
        ((JSAny? name, JSAny? options, JSAny? callback) => _Promise.reject(
          _JSError('test rejection'),
        )).toJS;
    try {
      var stopwatch = Stopwatch()..start();
      Object? error;
      try {
        await GlobalLock(
          newGlobalLockName(),
        ).acquire(timeout: const Duration(seconds: 30));
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect(error, isNot(isA<TimeoutException>()));
      expect(error.toString(), contains('test rejection'));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
    } finally {
      _locks.delete('request'.toJS);
    }
  });
}
