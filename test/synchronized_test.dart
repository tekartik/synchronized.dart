// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:synchronized/synchronized.dart';
import 'package:synchronized/src/synchronized_impl.dart' show SynchronizedLockImpl;
import 'package:dev_test/test.dart';

// To make tests less verbose...
class Lock extends SynchronizedLockImpl {}

void main() {
  group('synchronized', () {
    test('order', () async {
      Lock lock = new Lock();
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

    test('nested', () async {
      Lock lock = new Lock();
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
    });

    test('perf', () async {
      Stopwatch sw = new Stopwatch();
      sw.start();
      int count = 10000;
      Lock lock = new Lock();
      List<Future> futures = [];
      List<int> list = [];
      for (int i = 0; i < count; i++) {
        //await sleep(1);
        Future future = lock.synchronized(() async {
          list.add(i);
        });
        futures.add(future);
      }
      await Future.wait(futures);
      expect(list, new List.generate(count, (i) => i));
      print(sw.elapsed);
      // 2016-10-13 10000 0:00:00.692360 v0.1.0
      // 2016-10-05 10000 0:00:00.971284
    });

    test('throw', () async {
      Lock lock = new Lock();
      try {
        await lock.synchronized(() {
          throw "throwing";
        });
        fail("should throw");
      } catch (e) {
        expect(e is TestFailure, isFalse);
      }
    });

    test('exception', () async {
      Lock lock = new Lock();
      List<int> list = [];
      lock.synchronized(() async {
        list.add(1);
      });
      // catch the error
      lock.synchronized(() {
        throw "throwing";
      }).catchError((_) {
        list.add(2);
      });
      // only wait the last one
      await lock.synchronized(() async {
        list.add(3);
      });
      expect(list, [1, 2, 3]);
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

    skip_group('timeout', () {
      test('0_ms', () async {
        Lock lock = new Lock();
        Completer completer = new Completer();
        Future future = lock.synchronized(() async {
          await completer.future;
        });
        try {
          await lock.synchronized(null, timeout: new Duration());
          fail('should fail');
        } on TimeoutException catch (_) {}
        completer.complete();
        await future;
      });

      test('100_ms', () async {
        // hoping timint is ok...
        Lock lock = new Lock();

        // hold for 5ms
        Future future = lock.synchronized(() async {
          await new Future.delayed(new Duration(milliseconds: 50));
        });


        try {
          await lock.synchronized(null, timeout: new Duration(milliseconds: 1));
          fail('should fail');
        } on TimeoutException catch (_) {}

        try {
          await lock.synchronized(null, timeout: new Duration(milliseconds: 2));
          fail('should fail');
        } on TimeoutException catch (_) {}

        // waiting long enough
        await lock.synchronized(() {
        }, timeout: new Duration(milliseconds: 100));
      });


    });

    group('lock', () {
      test('locked', () async {
        // Make sure the lock state is made immediately
        // This ensure that calling locked then synchronized is atomic
        Lock lock = new Lock();
        Future future = lock.synchronized(null);
        expect(lock.locked, isTrue);

        await future;
      });

      test('immediacity', () async {
        Lock lock = new Lock();
        int value;
        Future future = lock.synchronized(() {
          value = 1;
        });
        // A sync method is executed right away!
        expect(value, 1);
        await future;
      });

      test('no immediacity', () async {
        Lock lock = new Lock();
        int value;
        Future future = lock.synchronized(() async {
          value = 1;
        });
        // A sync method is executed right away!
        expect(value, isNull);
        await future;
      });
    });
  });
}
