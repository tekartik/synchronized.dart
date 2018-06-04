// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dev_test/test.dart';
import 'package:synchronized/synchronized.dart' hide SynchronizedLock;

import 'lock_test.dart';
import 'test_common.dart';
import 'test_compat.dart';

main() {
  var lockFactory = new SynchronizedLockFactory();
  Lock newLock() => lockFactory.newLock();

  group('compat', () {
    group('synchronized', () {
      test('order', () async {
        var object = new Object();
        List<int> list = [];
        // ignore: deprecated_member_use
        Future future1 = synchronized(object, () async {
          list.add(1);
        });
        // ignore: deprecated_member_use
        Future<String> future2 = synchronized(object, () async {
          await new Duration(milliseconds: 10);
          list.add(2);
          return "text";
        });
        // ignore: deprecated_member_use
        Future<int> future3 = synchronized(object, () {
          list.add(3);
          return 1234;
        });
        await Future.wait([future1, future2, future3]);
        expect(await future1, isNull);
        expect(await future2, "text");
        expect(await future3, 1234);
        expect(list, [1, 2, 3]);
      });

      group('any_object', () {
        test('any_lock', () async {
          // ignore: deprecated_member_use
          await synchronized(new Object(), null);
        });
        test('null_lock', () async {
          try {
            // ignore: deprecated_member_use
            await synchronized(null, null);
            fail("should fail");
          } on ArgumentError catch (_) {}
        });

        test('string_lock', () async {
          // ignore: deprecated_member_use
          await synchronized("text", null);
        });
      });

      // https://github.com/tekartik/synchronized.dart/issues/1
      test('issue_1', () async {
        var value = '';

        // ignore: deprecated_member_use
        Future outer1 = synchronized('test', () async {
          expect(value, equals(''));
          value = 'outer1';

          await sleep(20);

          // ignore: deprecated_member_use
          await synchronized('test', () async {
            await sleep(30);
            expect(value, equals('outer1'));
            value = 'inner1';
          });
        });

        // ignore: deprecated_member_use
        Future outer2 = synchronized('test', () async {
          await sleep(30);
          expect(value, equals('inner1'));
          value = 'outer2';
        });

        Future outer3 = sleep(30).whenComplete(() {
          // ignore: deprecated_member_use
          return synchronized('test', () async {
            expect(value, equals('outer2'));
            value = 'outer3';
          });
        });

        await Future.wait([outer1, outer2, outer3]);

        expect(value, equals('outer3'));
      });
    });
  });
  group('SynchronizedLockCompat', () {
    lockMain(lockFactory);

    // only for reentrant-lock
    test('nested', () async {
      Lock lock = newLock();

      List<int> list = [];
      var future1 = lock.synchronized(() async {
        list.add(1);
        await lock.synchronized(() async {
          await new Duration(milliseconds: 10);
          list.add(2);
        });
        list.add(3);
      });
      var future2 = lock.synchronized(() {
        list.add(4);
      });
      await Future.wait([future1, future2]);
      expect(list, [1, 2, 3, 4]);
    });

    test('inner_value', () async {
      Lock lock = newLock();

      expect(
          await lock.synchronized(() async {
            expect(
                await lock.synchronized(() {
                  return "inner";
                }),
                "inner");
            return "outer";
          }),
          "outer");
    });

    test('inner_vs_outer', () async {
      Lock lock = newLock();

      List<int> list = [];
      lock.synchronized(() async {
        await sleep(1);
        list.add(1);
        // don't wait here on purpose
        // to make sure this task is started first
        lock.synchronized(() async {
          await sleep(1);
          list.add(2);
        });
      });
      await lock.synchronized(() async {
        list.add(3);
      });
      expect(list, [1, 2, 3]);
    });

    test('inner_no_wait', () async {
      Lock lock = newLock();
      List<int> list = [];
      await lock.synchronized(() async {
        await sleep(1);
        list.add(1);
        // don't wait here on purpose
        // to make sure this task is started first
        lock.synchronized(() async {
          await sleep(1);
          list.add(3);
        });
      });
      list.add(2);
      await lock.synchronized(() async {
        list.add(4);
      });
      expect(list, [1, 2, 3, 4]);
    });

    test('two_locks', () async {
      var lock1 = newLock();
      var lock2 = newLock();

      expect(Zone.current[lock1], isNull);

      bool ok;
      await lock1.synchronized(() async {
        expect(Zone.current[lock1], isNotNull);
        expect(Zone.current[lock2], isNull);
        await lock2.synchronized(() async {
          expect(Zone.current[lock2], isNotNull);
          expect(Zone.current[lock1], isNotNull);
          expect(lock1.locked, isFalse);
          expect(lock2.locked, isFalse);
          ok = true;
        });
      });
      expect(ok, isTrue);
    });

    group('error', () {
      test('inner_throw', () async {
        Lock lock = newLock();
        try {
          await lock.synchronized(() async {
            await lock.synchronized(() {
              throw "throwing";
            });
          });
          fail("should throw");
        } catch (e) {
          expect(e is TestFailure, isFalse);
        }

        await lock.synchronized(() {});
      });

      test('inner_throw_async', () async {
        Lock lock = newLock();
        try {
          await lock.synchronized(() async {
            await lock.synchronized(() async {
              throw "throwing";
            });
          });
          fail("should throw");
        } catch (e) {
          expect(e is TestFailure, isFalse);
        }
        await sleep(1);
      });
    });
  });
}
