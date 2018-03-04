// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:synchronized/src/synchronized_impl.dart';
//import 'package:synchronized/synchronized.dart';
import 'package:dev_test/test.dart';

// To make tests less verbose...
class _Lock extends SynchronizedLock {
  _Lock() : super.impl();
}

void main() {
  group('synchronized_impl', () {
    group('Lock', () {
      group('Lock', () {
        test('taskRunning', () {});
        test('toString', () {
          var lock = new Lock();
          expect("$lock", startsWith("Lock["));
          expect("$lock", endsWith("]"));
        });
      });
    });

    group('SynchronizedLock', () {
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

        test('toString', () {
          var lock = new SynchronizedLock('test');
          expect("$lock", "SynchronizedLock[test]");
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
          expect(synchronizedLocks, isEmpty);
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

        test('inner_no_wait', () async {
          expect(synchronizedLocks, isEmpty);

          Completer beforeInnerCompleter = new Completer.sync();
          Future future = synchronized("test", () async {
            await sleep(1);
            beforeInnerCompleter.complete();

            // no wait here on purpose
            synchronized("test", () {});
          });
          expect(synchronizedLocks, hasLength(1));
          await beforeInnerCompleter.future;
          expect(synchronizedLocks, hasLength(1));
          await future;
          expect(synchronizedLocks, isEmpty);
        });

        test('inner_no_wait_async', () async {
          expect(synchronizedLocks, isEmpty);

          Completer beforeInnerCompleter = new Completer.sync();
          Future future = synchronized("test", () async {
            await sleep(1);
            beforeInnerCompleter.complete();

            // no wait here on purpose
            synchronized("test", () async {});
          });
          expect(synchronizedLocks, hasLength(1));
          await beforeInnerCompleter.future;
          expect(synchronizedLocks, hasLength(1));
          await future;
          // There will be a delay when the locks are cleaned-up here
          expect(synchronizedLocks, isNotEmpty);
          await sleep(0);
          expect(synchronizedLocks, isEmpty);
        });
      });

      group('locked', () {
        test('simple', () async {
          // Make sure the lock state is made immediately
          // This ensure that calling locked then synchronized is atomic
          _Lock lock = new _Lock();
          expect(lock.locked, isFalse);
          Future future = lock.synchronized(null);
          expect(lock.locked, isTrue);
          await future;
          expect(lock.locked, isFalse);
        });

        test('inner', () async {
          _Lock lock = new _Lock();
          Completer completer = new Completer();
          Completer innerCompleter = new Completer();
          Future future = lock.synchronized(() async {
            // don't wait here
            lock.synchronized(() async {
              await sleep(1);
              await innerCompleter.future;
            });
            await completer.future;
          });
          expect(lock.locked, isTrue);
          completer.complete();
          try {
            await lock.synchronized(null,
                timeout: new Duration(milliseconds: 100));
            fail('should fail');
          } on TimeoutException catch (_) {}
          expect(lock.locked, isTrue);
          innerCompleter.complete();
          await future;
          expect(lock.locked, isFalse);
        });
      });

      group('immediacity', () {
        test('sync', () async {
          _Lock lock = new _Lock();
          int value;
          Future future = lock.synchronized(() {
            value = 1;
          });
          // A sync method is executed right away!
          expect(value, 1);
          await future;
        });

        test('async', () async {
          _Lock lock = new _Lock();
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
          _Lock lock1 = new _Lock();
          _Lock lock2 = new _Lock();
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
          _Lock lock = new _Lock();
          Future future = lock.synchronized(() async {
            expect(lock.inZone, isTrue);

            expect(lock.tasks.length, 1);
            expect(lock.tasks.last.innerFutures, isNull);
            // don't wait here
            lock.synchronized(() async {
              expect(lock.tasks.length, 1);
              expect(lock.tasks.last.innerFutures.length, 1);
              expect(lock.inZone, isTrue);
              await sleep(10);
              expect(lock.inZone, isTrue);
              expect(lock.tasks.length, 1);
            });
            expect(lock.tasks.last.innerFutures.length, 1);
          });
          expect(lock.inZone, isFalse);
          await future;
          expect(lock.inZone, isFalse);
        });

        test('inner_vs_outer', () async {
          List<int> list = [];
          _Lock lock = new _Lock();
          Future future = lock.synchronized(() async {
            await sleep(10);
            // don't wait here
            lock.synchronized(() async {
              await sleep(20);
              list.add(1);
            });
          });
          expect(lock.inZone, isFalse);
          Future future2 = lock.synchronized(() async {
            await sleep(10);
            list.add(2);
          });
          Future future3 = sleep(20).whenComplete(() async {
            await lock.synchronized(() async {
              list.add(3);
            });
          });
          await Future.wait([future, future2, future3]);
          expect(list, [1, 2, 3]);
        });
      });
    });
  });
}
