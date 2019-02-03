// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:synchronized/src/synchronized_impl.dart' show ReentrantLock;
import 'package:test/test.dart';
import 'test_common.dart';

// To make tests less verbose...
class Lock extends ReentrantLock {
  Lock() : super.impl();
}

void main() {
  group('synchronized', () {
    test('demo', () {});

    test('order', () async {
      var isNewTiming = await isDart2AsyncTiming();
      Lock lock = Lock();
      List<int> list = [];
      Future future1 = lock.synchronized(() async {
        list.add(1);
      });
      Future<String> future2 = lock.synchronized(() async {
        await sleep(10);
        list.add(2);
        return "text";
      });
      Future<int> future3 = lock.synchronized(() {
        list.add(3);
        return 1234;
      });
      if (isNewTiming) {
        expect(list, [1]);
      } else {
        expect(list, isEmpty);
      }
      await Future.wait([future1, future2, future3]);
      expect(await future1, isNull);
      expect(await future2, "text");
      expect(await future3, 1234);
      expect(list, [1, 2, 3]);
    });

    test('nested', () async {
      Lock lock = Lock();
      List<int> list = [];
      Future future1 = lock.synchronized(() async {
        list.add(1);
        await lock.synchronized(() async {
          await sleep(10);
          list.add(2);
        });
        list.add(3);
      });
      Future future2 = lock.synchronized(() {
        list.add(4);
      });
      await Future.wait([future1, future2]);
      expect(list, [1, 2, 3, 4]);
    });

    test('queued_value', () async {
      Lock lock = Lock();
      Future<String> value1 = lock.synchronized(() async {
        await sleep(1);
        return "value1";
      });
      expect(await lock.synchronized(() => "value2"), "value2");
      expect(await value1, "value1");
    });

    test('inner_value', () async {
      Lock lock = Lock();
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
      Lock lock = Lock();
      List<int> list = [];
      // ignore: unawaited_futures
      lock.synchronized(() async {
        await sleep(1);
        list.add(1);
        // don't wait here on purpose
        // to make sure this task is started first
        // ignore: unawaited_futures
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
      Lock lock = Lock();
      List<int> list = [];
      await lock.synchronized(() async {
        await sleep(1);
        list.add(1);
        // don't wait here on purpose
        // to make sure this task is started first
        // ignore: unawaited_futures
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

    group('timeout', () {
      test('0_ms', () async {
        Lock lock = Lock();
        Completer completer = Completer();
        Future future = lock.synchronized(() async {
          await completer.future;
        });
        try {
          await lock.synchronized(null, timeout: Duration(milliseconds: 1));
          fail('should fail');
        } on TimeoutException catch (_) {}
        completer.complete();
        await future;
      });

      test('100_ms', () async {
        // hoping timint is ok...
        Lock lock = Lock();

        bool ran1 = false;
        bool ran2 = false;
        bool ran3 = false;
        // hold for 5ms
        // ignore: unawaited_futures
        lock.synchronized(() async {
          await Future.delayed(Duration(milliseconds: 50));
        });

        try {
          await lock.synchronized(() {
            ran1 = true;
          }, timeout: Duration(milliseconds: 1));
        } on TimeoutException catch (_) {}

        try {
          await lock.synchronized(() {
            ran2 = true;
          }, timeout: Duration(milliseconds: 2));
          fail('should fail');
        } on TimeoutException catch (_) {}

        // waiting long enough
        await lock.synchronized(() {
          ran3 = true;
        }, timeout: Duration(milliseconds: 100));

        expect(ran1, isFalse);
        expect(ran2, isFalse);
        expect(ran3, isTrue);
      });
    });

    group('error', () {
      test('throw', () async {
        Lock lock = Lock();
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
        Lock lock = Lock();

        // delay so that it is queued
        // ignore: unawaited_futures
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
        Lock lock = Lock();
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
        Lock lock = Lock();
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
        Lock lock = Lock();

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

    group('lock', () {});
  });
}
