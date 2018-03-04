// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dev_test/test.dart';
import 'package:synchronized/src/synchronized_impl.dart' show sleep;
import 'package:synchronized/synchronized.dart';
import 'test_common.dart';

main() {
  group('Lock', () {
    lockMain();
  });
}

void lockMain([LockFactory lockFactory]) {
  lockFactory ??= new LockFactory();

  Lock newLock() => lockFactory.newLock();

  group('synchronized', () {
    test('order', () async {
      Lock lock = newLock();
      List<int> list = [];
      Future future1 = lock.synchronized(() async {
        list.add(1);
      });
      Future<String> future2 = lock.synchronized(() async {
        await new Duration(milliseconds: 10);
        list.add(2);
        return "text";
      });
      Future<int> future3 = lock.synchronized(() {
        list.add(3);
        return 1234;
      });
      expect(list, isEmpty);
      await Future.wait([future1, future2, future3]);
      expect(await future1, isNull);
      expect(await future2, "text");
      expect(await future3, 1234);
      expect(list, [1, 2, 3]);
    });

    // only for reentrant-lock
    test('nested', () async {
      Lock lock = newLock();
      if (lock is SynchronizedLock) {
        List<int> list = [];
        Future future1 = lock.synchronized(() async {
          list.add(1);
          await lock.synchronized(() async {
            await new Duration(milliseconds: 10);
            list.add(2);
          });
          list.add(3);
        });
        Future future2 = lock.synchronized(() {
          list.add(4);
        });
        await Future.wait([future1, future2]);
        expect(list, [1, 2, 3, 4]);
      }
    });

    test('queued_value', () async {
      Lock lock = newLock();
      Future<String> value1 = lock.synchronized(() async {
        await sleep(1);
        return "value1";
      });
      expect(await lock.synchronized(() => "value2"), "value2");
      expect(await value1, "value1");
    });

    test('inner_value', () async {
      Lock lock = newLock();
      if (lock is SynchronizedLock) {
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
      }
    });

    test('inner_vs_outer', () async {
      Lock lock = newLock();
      if (lock is SynchronizedLock) {
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
      }
    });

    test('inner_no_wait', () async {
      Lock lock = newLock();
      if (lock is SynchronizedLock) {
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
      }
    });

    group('perf', () {
      int operationCount = 10000;

      test('$operationCount operations', () async {
        int count = operationCount;
        int j;

        Stopwatch sw = new Stopwatch();
        j = 0;
        sw.start();
        for (int i = 0; i < count; i++) {
          j += i;
        }
        print(" none ${sw.elapsed}");
        expect(j, count * (count - 1) / 2);

        sw = new Stopwatch();
        j = 0;
        sw.start();
        for (int i = 0; i < count; i++) {
          await () async {
            j += i;
          }();
        }
        print("await ${sw.elapsed}");
        expect(j, count * (count - 1) / 2);

        var lock = newLock();
        sw = new Stopwatch();
        j = 0;
        sw.start();
        for (int i = 0; i < count; i++) {
          lock.synchronized(() {
            j += i;
          });
        }
        await lock.synchronized(() => {});
        print("syncd ${sw.elapsed}");
        expect(j, count * (count - 1) / 2);

        // 2018-03-04
        /*
        00:00 +0: test/lock_test.dart: Lock synchronized perf 100000 operations
         none 0:00:00.006750
        await 0:00:00.767625
        syncd 0:00:19.848688
        00:21 +1: test/synchronized_lock_test.dart: SynchronizedLock synchronized perf 100000 operations
         none 0:00:00.002337
        await 0:00:00.838564
        syncd 0:00:20.403227

        */

        // For 100 000 operations
        // 00:00 +0: test/lock_test.dart: synchronized perf 10000 operations
        // without synchronized
        // none 0:00:00.012020
        // await 0:00:00.849461
        // syncd 0:00:19.949695
        // 00:21 +1: test/synchronized_lock_test.dart: SynchronizedLock synchronized perf 10000 operations
        // without synchronized
        // none 0:00:00.002947
        // await 0:00:00.902111
        // syncd 0:00:20.247085

        // 2016-10-14
        // 0:00:00.000201
        // 0:00:00.221551
        // 0:00:00.404036

        // 2017-10-15
        // 0:00:00.000381
        // 0:00:00.161558
        // 0:00:00.603976
      });
    });

    group('any_object', () {
      test('null_lock', () async {
        await synchronized(new Object(), null);
        try {
          await synchronized(null, null);
          fail("should fail");
        } on ArgumentError catch (_) {}
      });

      test('string_lock', () async {
        await synchronized(new Object(), null);
        try {
          await synchronized(null, null);
          fail("should fail");
        } on ArgumentError catch (_) {}
      });
    });

    group('timeout', () {
      test('0_ms', () async {
        Lock lock = newLock();
        Completer completer = new Completer();
        Future future = lock.synchronized(() async {
          await completer.future;
        });
        try {
          await lock.synchronized(null, timeout: new Duration(milliseconds: 1));
          fail('should fail');
        } on TimeoutException catch (_) {}
        completer.complete();
        await future;
      });

      test('100_ms', () async {
        // hoping timint is ok...
        Lock lock = newLock();

        bool ran1 = false;
        bool ran2 = false;
        bool ran3 = false;
        // hold for 5ms
        lock.synchronized(() async {
          await new Future.delayed(new Duration(milliseconds: 50));
        });

        try {
          await lock.synchronized(() {
            ran1 = true;
          }, timeout: new Duration(milliseconds: 1));
        } on TimeoutException catch (_) {}

        try {
          await lock.synchronized(() {
            ran2 = true;
          }, timeout: new Duration(milliseconds: 2));
          fail('should fail');
        } on TimeoutException catch (_) {}

        // waiting long enough
        await lock.synchronized(() {
          ran3 = true;
        }, timeout: new Duration(milliseconds: 100));

        expect(ran1, isFalse);
        expect(ran2, isFalse);
        expect(ran3, isTrue);
      });
    });

    group('error', () {
      test('throw', () async {
        Lock lock = newLock();
        try {
          await lock.synchronized(() {
            throw "throwing";
          });
          fail("should throw");
        } catch (e) {
          expect(e is TestFailure, isFalse);
        }

        await lock.synchronized(() {});
      });

      test('queued_throw', () async {
        Lock lock = newLock();

        // delay so that it is queued
        lock.synchronized(() {
          return sleep(1);
        });
        try {
          await lock.synchronized(() async {
            throw "throwing";
          });
          fail("should throw");
        } catch (e) {
          expect(e is TestFailure, isFalse);
        }

        await lock.synchronized(() {});
      });

      test('throw_async', () async {
        Lock lock = newLock();
        try {
          await lock.synchronized(() async {
            throw "throwing";
          });
          fail("should throw");
        } catch (e) {
          expect(e is TestFailure, isFalse);
        }
      });

      test('inner_throw', () async {
        Lock lock = newLock();
        if (lock is SynchronizedLock) {
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
        }
      });

      test('inner_throw_async', () async {
        Lock lock = newLock();
        if (lock is SynchronizedLock) {
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
        }
      });
    });

    group('lock', () {});
  });
}