// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:synchronized/src/synchronized_impl.dart' show sleep;
import 'lock_test.dart';
import 'package:dev_test/test.dart';
import 'package:synchronized/synchronized.dart' hide SynchronizedLock;
import 'test_common.dart';

main() {
  var lockFactory = new SynchronizedLockFactory();
  Lock newLock() => lockFactory.newLock();

  group('SynchronizedLock', () {
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
