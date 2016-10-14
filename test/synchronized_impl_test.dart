// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:synchronized/src/synchronized_impl.dart';
//import 'package:synchronized/synchronized.dart';
import 'package:dev_test/test.dart';

// To make tests less verbose...
class Lock extends SynchronizedLock {
  Lock() : super.impl();
}

void main() {
  group('synchronized_impl', () {
    group('makeSynchronizedLock', () {
      test('equals', () async {
        SynchronizedLock lock1 = makeSynchronizedLock("test");
        SynchronizedLock lock2 = makeSynchronizedLock("test");
        expect(lock1, same(lock2));
        SynchronizedLock lock3 = new SynchronizedLock("test");
        expect(lock1, same(lock3));
        // clear for next tests
        synchronizedLocks.clear();
      });
      test('simple', () async {
        expect(synchronizedLocks, isEmpty);
        SynchronizedLock lockImpl = makeSynchronizedLock("test");
        expect(lockImpl.monitor, "test");
        expect(synchronizedLocks, hasLength(1));
        // clear for next tests
        synchronizedLocks.clear();
      });
    });

    group('SynchronizedLock', () {
      test('equals', () async {
        SynchronizedLock lock1 = new SynchronizedLock();
        SynchronizedLock lock2 = new SynchronizedLock();

        expect(lock1, isNot(lock2));
        expect(synchronizedLocks, isEmpty);
        lock1 = new SynchronizedLock("test");
        lock2 = new SynchronizedLock("test");
        expect(lock1, same(lock2));
        expect(synchronizedLocks, hasLength(1));
        // clear for next tests
        synchronizedLocks.clear();
      });

      test('ready', () async {
        SynchronizedLock lock = new SynchronizedLock();
        await lock.ready;

        bool done = false;
        lock.synchronized(() async {
          await sleep(100);
          done = true;
        });

        try {
          await lock.ready.timeout(new Duration(milliseconds: 1));
          fail('should fail');
        } on TimeoutException catch (_) {}

        expect(done, isFalse);
        await lock.ready;
        expect(done, isTrue);
        ;
      });
    });
    group('synchronizedLocks', () {
      test('content', () async {
        expect(synchronizedLocks, isEmpty);

        Future future = synchronized("test", () async {
          await sleep(1);
        });
        expect(synchronizedLocks, hasLength(1));
        await future;
        expect(synchronizedLocks, isEmpty);
      });

      test('content_2', () async {
        expect(synchronizedLocks, isEmpty);

        synchronized("test", () async {
          await sleep(1);
        });
        Future future = synchronized("test", () async {
          await sleep(1);
        });
        expect(synchronizedLocks, hasLength(1));
        await future;
        expect(synchronizedLocks, isEmpty);
      });

      test('inner', () async {
        expect(synchronizedLocks, isEmpty);

        Completer beforeInnerCompleter = new Completer.sync();
        Future future = synchronized("test", () async {
          await sleep(1);
          beforeInnerCompleter.complete();
          await synchronized("test", () async {
            await sleep(1);
          });
        });
        expect(synchronizedLocks, hasLength(1));
        await beforeInnerCompleter.future;
        expect(synchronizedLocks, hasLength(1));
        await future;
        expect(synchronizedLocks, isEmpty);
      });
    });

    group('locked', () {
      test('simple', () async {
        // Make sure the lock state is made immediately
        // This ensure that calling locked then synchronized is atomic
        Lock lock = new Lock();
        expect(lock.locked, isFalse);
        Future future = lock.synchronized(null);
        expect(lock.locked, isTrue);
        await future;
        expect(lock.locked, isFalse);
      });

      test('inner', () async {
        Lock lock = new Lock();
        Completer completer = new Completer();
        Completer innerCompleter = new Completer();
        Future innerFuture;
        Future future = lock.synchronized(() async {
          // don't wait here
          innerFuture = lock.synchronized(() async {
            sleep(0);
            await innerCompleter.future;
          });
          await completer.future;
        });
        expect(lock.locked, isTrue);
        completer.complete();
        await future;
        expect(lock.locked, isTrue);
        innerCompleter.complete();
        await innerFuture;
        expect(lock.locked, isFalse);
      });
    });

    group('immediacity', () {
      test('sync', () async {
        Lock lock = new Lock();
        int value;
        Future future = lock.synchronized(() {
          value = 1;
        });
        // A sync method is executed right away!
        expect(value, 1);
        await future;
      });

      test('async', () async {
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
    group('inZone', () {
      test('two_locks', () async {
        Lock lock1 = new Lock();
        Lock lock2 = new Lock();
        Completer completer = new Completer();
        Future future = lock1.synchronized(() async {
          expect(lock1.inZone, isTrue);
          expect(lock2.inZone, isFalse);
          await completer.future;
        });
        expect(lock1.inZone, isFalse);
        completer.complete();
        await future;
      });

      test('inner', () async {
        Lock lock = new Lock();
        Completer completer = new Completer();
        Completer innerCompleter = new Completer();
        Future future = lock.synchronized(() async {
          expect(lock.inZone, isTrue);

          // don't wait here
          lock.synchronized(() async {
            expect(lock.inZone, isTrue);
            sleep(1);
            expect(lock.inZone, isTrue);
            await innerCompleter.future;
          });
          await completer.future;
        });
        expect(lock.inZone, isFalse);
        completer.complete();
        await future;
        expect(lock.locked, isTrue);
      });
    });

    group('perf', () {
      test('10000 operations', () async {
        int count = 10000;
        int j;

        Stopwatch sw = new Stopwatch();
        j = 0;
        sw.start();
        for (int i = 0; i < count; i++) {
          j += i;
        }
        print(sw.elapsed);
        expect(j, count * (count - 1) / 2);

        sw = new Stopwatch();
        j = 0;
        sw.start();
        for (int i = 0; i < count; i++) {
          await () async {
            j += i;
          }();
        }
        print(sw.elapsed);
        expect(j, count * (count - 1) / 2);

        SynchronizedLock lock = new SynchronizedLock();
        sw = new Stopwatch();
        j = 0;
        sw.start();
        for (int i = 0; i < count; i++) {
          lock.synchronized(() {
            j += i;
          });
        }
        await lock.ready;
        print(sw.elapsed);
        expect(j, count * (count - 1) / 2);

        // 2016-10-14
        // 0:00:00.000201
        // 0:00:00.221551
        // 0:00:00.404036
      });
    });
  });
}
