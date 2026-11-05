import 'dart:async';
import 'dart:math';

import 'package:synchronized/global_lock.dart';
import 'package:test/test.dart';

import 'src/global_lock_test_utils.dart';

/// Long enough for a lock released by another holder (io retries).
const _acquireTimeout = Duration(seconds: 10);

void main() {
  group('GlobalLock', () {
    test('name', () {
      var name = newGlobalLockName();
      var lock = GlobalLock(name);
      expect(lock.name, name);
      expect(lock.toString(), 'GlobalLock($name)');
    });

    test('synchronized value', () async {
      var lock = GlobalLock(newGlobalLockName());
      expect(await lock.synchronized(() => 1), 1);
      expect(await lock.synchronized(() async => 2), 2);
    });

    test('synchronized error releases', () async {
      var lock = GlobalLock(newGlobalLockName());
      await expectLater(
        lock.synchronized(() => throw StateError('test')),
        throwsStateError,
      );
      expect(await lock.synchronized(() => 1, timeout: _acquireTimeout), 1);
    });

    test('concurrent calls serialized', () async {
      var name = newGlobalLockName();
      var running = 0;
      var maxRunning = 0;
      var done = 0;
      await Future.wait(
        List.generate(
          5,
          (i) => GlobalLock(name).synchronized(() async {
            running++;
            maxRunning = max(maxRunning, running);
            await Future<void>.delayed(const Duration(milliseconds: 20));
            running--;
            done++;
          }),
        ),
      );
      expect(maxRunning, 1);
      expect(done, 5);
    });

    test('timeout while held', () async {
      var name = newGlobalLockName();
      var handle = await GlobalLock(name).acquire();
      var other = GlobalLock(name);
      var called = false;
      await expectLater(
        other.synchronized(() {
          called = true;
        }, timeout: const Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        other.acquire(timeout: Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
      expect(called, isFalse);
      await handle.release();
      handle = await other.acquire(timeout: _acquireTimeout);
      await handle.release();
    });

    test('timeout zero when free', () async {
      var lock = GlobalLock(newGlobalLockName());
      var handle = await lock.acquire(timeout: Duration.zero);
      await handle.release();
    });

    test('wait for release', () async {
      var name = newGlobalLockName();
      var handle = await GlobalLock(name).acquire();
      var acquired = false;
      var future = GlobalLock(name).synchronized(() {
        acquired = true;
      }, timeout: _acquireTimeout);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(acquired, isFalse);
      await handle.release();
      await future;
      expect(acquired, isTrue);
    });

    test('other name not blocked', () async {
      var handle = await GlobalLock(newGlobalLockName()).acquire();
      try {
        expect(
          await GlobalLock(
            newGlobalLockName(),
          ).synchronized(() => 1, timeout: _acquireTimeout),
          1,
        );
      } finally {
        await handle.release();
      }
    });

    test('release twice', () async {
      var lock = GlobalLock(newGlobalLockName());
      var handle = await lock.acquire();
      await handle.release();
      await handle.release();
      handle = await lock.acquire(timeout: _acquireTimeout);
      await handle.release();
    });
  });
}
