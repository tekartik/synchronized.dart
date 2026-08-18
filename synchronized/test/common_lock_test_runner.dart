// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:synchronized/src/basic_lock.dart' show BasicLock;
import 'package:synchronized/src/reentrant_lock.dart' show ReentrantLock;
import 'package:synchronized/synchronized.dart';
import 'package:test/test.dart';

import 'lock_factory.dart';
import 'perf_test_runner.dart' show lockPerfTest;

void main() {
  lockMain(BasicLockFactory());
}

void lockMain(LockFactory lockFactory) {
  Lock newLock() => lockFactory.newLock();

  group('synchronized', () {
    test('two_locks', () async {
      var lock1 = newLock();
      var lock2 = newLock();

      bool? ok;
      await lock1.synchronized(() async {
        await lock2.synchronized(() async {
          expect(lock1.locked, isTrue);
          expect(lock2.locked, isTrue);
          ok = true;
        });
      });
      expect(ok, isTrue);
    });

    test('order', () async {
      final lock = newLock();
      final list = <int>[];
      final future1 = lock.synchronized(() async {
        list.add(1);
      });
      final future2 = lock.synchronized(() async {
        await sleep(10);
        list.add(2);
        return 'text';
      });
      final future3 = lock.synchronized(() {
        list.add(3);
        return 1234;
      });
      expect(list, [1]);
      await Future.wait([future1, future2, future3]);
      expect(await future1, isNull);
      expect(await future2, 'text');
      expect(await future3, 1234);
      expect(list, [1, 2, 3]);
    });

    test('queued_value', () async {
      final lock = newLock();
      final value1 = lock.synchronized(() async {
        await sleep(1);
        return 'value1';
      });
      expect(await lock.synchronized(() => 'value2'), 'value2');
      expect(await value1, 'value1');
    });

    group('perf', () {
      // A small smoke run of the manual benchmark: it stresses the queue and
      // asserts the lock drains. See perf_test_runner.dart to run it for real.
      lockPerfTest(lockFactory, operationCount: 10000);
    });

    group('timeout', () {
      test('1_ms', () async {
        final lock = newLock();
        final completer = Completer<void>();
        final future = lock.synchronized(() async {
          await completer.future;
        });
        try {
          await lock.synchronized(
            () {},
            timeout: const Duration(milliseconds: 1),
          );
          fail('should fail');
        } on TimeoutException catch (_) {}
        completer.complete();
        await future;
      });

      test('100_ms', () async {
        // var isNewTiming = await isDart2AsyncTiming();
        // hoping timint is ok...
        final lock = newLock();

        var ran1 = false;
        var ran2 = false;
        var ran3 = false;
        var ran4 = false;
        // hold for 5ms
        // ignore: unawaited_futures
        lock.synchronized(() async {
          await sleep(1000);
        });

        try {
          await lock.synchronized(() {
            ran1 = true;
          }, timeout: const Duration(milliseconds: 1));
        } on TimeoutException catch (_) {}

        try {
          await lock.synchronized(() async {
            await sleep(5000);
            ran2 = true;
          }, timeout: const Duration(milliseconds: 1));
          fail('should time out while the lock is held');
        } on TimeoutException catch (_) {}

        try {
          // ignore: unawaited_futures
          lock.synchronized(() {
            ran4 = true;
          }, timeout: const Duration(milliseconds: 2000));
        } on TimeoutException catch (_) {}

        // waiting long enough
        await lock.synchronized(() {
          ran3 = true;
        }, timeout: const Duration(milliseconds: 2000));

        expect(ran1, isFalse, reason: 'ran1 should be false');
        expect(ran2, isFalse, reason: 'ran2 should be false');
        expect(ran3, isTrue, reason: 'ran3 should be true');
        expect(ran4, isTrue, reason: 'ran4 should be true');
      });

      test('1_ms_with_error', () async {
        var ok = false;
        var okTimeout = false;
        final lock = newLock();
        final completer = Completer<void>();
        // The holder fails on purpose; its error must not leak to the
        // waiters, so it is swallowed here and nowhere else.
        unawaited(
          lock
              .synchronized(() async {
                await completer.future;
              })
              .catchError((Object _) {}),
        );
        try {
          await lock.synchronized(
            () {},
            timeout: const Duration(milliseconds: 1),
          );
          fail('should fail');
        } on TimeoutException catch (_) {}
        completer.completeError('error');

        // Make sure these blocks ran: a failed holder must still release.
        await lock.synchronized(() {
          ok = true;
        });
        await lock.synchronized(() {
          okTimeout = true;
        }, timeout: const Duration(milliseconds: 1000));
        expect(ok, isTrue);
        expect(okTimeout, isTrue);
      });
    });

    group('error', () {
      test('throw', () async {
        final lock = newLock();
        await expectLater(
          lock.synchronized(() {
            throw StateError('throwing');
          }),
          throwsA(isA<StateError>()),
        );

        var ok = false;
        await lock.synchronized(() {
          ok = true;
        });
        expect(ok, isTrue);
      });

      test('queued_throw', () async {
        final lock = newLock();

        // delay so that it is queued
        // ignore: unawaited_futures
        lock.synchronized(() {
          return sleep(1);
        });
        await expectLater(
          lock.synchronized(() async {
            throw StateError('throwing');
          }),
          throwsA(isA<StateError>()),
        );

        var ok = false;
        await lock.synchronized(() {
          ok = true;
        });
        expect(ok, isTrue);
      });

      test('throw_async', () async {
        final lock = newLock();
        await expectLater(
          lock.synchronized(() async {
            throw StateError('throwing');
          }),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('immediacity', () {
      test('sync', () async {
        var lock = newLock();
        int? value;
        final future = lock.synchronized(() {
          value = 1;
          return Future<void>.value().then((_) {
            value = 2;
          });
        });
        // A sync method is executed right away!
        expect(value, 1);
        await future;
        expect(value, 2);
      });

      test('async', () async {
        var lock = newLock();
        int? value;
        final future = lock.synchronized(() async {
          value = 1;
          return Future<void>.value().then((_) {
            value = 2;
          });
        });
        // A sync method is executed right away!
        expect(value, 1);

        await future;
        expect(value, 2);
      });
    });

    group('locked', () {
      test('simple', () async {
        // Make sure the lock state is made immediately
        // when the function is not async
        var lock = newLock();
        expect(lock.locked, isFalse);
        final future = lock.synchronized(() => {});

        expect(lock.locked, isFalse);
        await future;
        expect(lock.locked, isFalse);
      });

      test('simple_async', () async {
        // Make sure the lock state is lazy for async method
        var lock = newLock();
        expect(lock.locked, isFalse);
        final future = lock.synchronized(() async => {});
        expect(lock.locked, isTrue);
        await future;
        expect(lock.locked, isFalse);
      });
    });
    group('locked_in_lock', () {
      test('two', () async {
        var lock = newLock();

        expect(lock.locked, isFalse);
        expect(lock.inLock, isFalse);
        await lock.synchronized(() async {
          expect(lock.locked, isTrue);
          expect(lock.inLock, isTrue);
        });
        expect(lock.locked, isFalse);
        expect(lock.inLock, isFalse);

        unawaited(
          lock.synchronized(() async {
            await sleep(1);
            expect(lock.locked, isTrue);
            expect(lock.inLock, isTrue);
          }),
        );

        await lock.synchronized(() async {
          await sleep(1);
          expect(lock.locked, isTrue);
          expect(lock.inLock, isTrue);
        });
        expect(lock.locked, isFalse);
        expect(lock.inLock, isFalse);
      });

      test('simple', () async {
        var lock = newLock();

        expect(lock.locked, isFalse);
        expect(lock.inLock, isFalse);
        await lock.synchronized(() async {
          expect(lock.locked, isTrue);
          expect(lock.inLock, isTrue);
        });
        expect(lock.locked, isFalse);
        expect(lock.inLock, isFalse);
      });

      test('locked/canLock', () async {
        final lock = newLock();
        expect(lock.locked, isFalse);
        expect(lock.inLock, isFalse);
        final future = lock.synchronized(() async {
          expect(lock.locked, isTrue);
          expect(lock.inLock, isTrue);
          if (lock is BasicLock) {
            expect(lock.canLock, isFalse);
          } else if (lock is ReentrantLock) {
            expect(lock.canLock, isTrue);
          }
        });
        expect(lock.locked, isTrue);
        expect(lock.canLock, isFalse);

        if (lock is ReentrantLock) {
          expect(lock.inLock, isFalse);
        } else if (lock is BasicLock) {
          expect(lock.inLock, isTrue);
        }

        await future;
        expect(lock.locked, isFalse);
        expect(lock.inLock, isFalse);
      });

      test('locked_with_timeout', () async {
        final lock = newLock();
        final completer = Completer<void>();

        // Lock it forever
        final future = lock.synchronized(() async {
          await completer.future;
        });
        expect(lock.locked, isTrue);

        await expectLater(
          lock.synchronized(() {}, timeout: const Duration(milliseconds: 100)),
          throwsA(isA<TimeoutException>()),
        );
        expect(lock.locked, isTrue);
        // Release the forever waiting lock
        completer.complete();
        await future;
        expect(lock.locked, isFalse);

        // Should succeed right away
        await lock.synchronized(() {}, timeout: const Duration(seconds: 10));
      });
    });

    test('synchronizedSync', () async {
      final lock = newLock();
      final list = <int>[];
      int add(int value) {
        list.add(value);
        return value;
      }

      final futureOr1 = lock.synchronizedSync(() {
        return add(1);
      });
      expect(list, [1]);
      expect(futureOr1, 1);
      final future1 = lock.synchronized(() async {
        await sleep(10);
        return add(2);
      });
      final futureOr3 = lock.synchronizedSync(() {
        return add(3);
      });
      expect(futureOr3, isA<Future>());
      expect(await future1, 2);
      expect(await futureOr3, 3);

      expect(list, [1, 2, 3]);
    });

    group('synchronizedSync async computation', () {
      // The lock is released as soon as the computation returns, so a Future
      // result would complete outside the lock. Both paths must assert:
      // which one runs depends on contention, so a one-sided check would
      // only catch the misuse some of the time.
      test('asserts on the immediate path', () {
        final lock = newLock();
        expect(lock.canLock, isTrue);
        expect(
          () => lock.synchronizedSync(() => Future<void>.value()),
          throwsA(isA<AssertionError>()),
        );
      });

      test('asserts on the queued path', () async {
        final lock = newLock();
        final completer = Completer<void>();
        // Hold the lock so synchronizedSync has to queue.
        final held = lock.synchronized(() => completer.future);
        expect(lock.canLock, isFalse);

        final queued = lock.synchronizedSync(() => Future<void>.value());
        completer.complete();
        await expectLater(queued, throwsA(isA<AssertionError>()));
        await held;
      });

      test('synchronous computation is unaffected', () async {
        final lock = newLock();
        expect(lock.synchronizedSync(() => 1), 1);

        final completer = Completer<void>();
        final held = lock.synchronized(() => completer.future);
        final queued = lock.synchronizedSync(() => 2);
        expect(queued, isA<Future>());
        completer.complete();
        expect(await queued, 2);
        await held;
      });
    });
  });
}
