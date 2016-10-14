// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:synchronized/src/synchronized_impl.dart';
import 'package:synchronized/synchronized.dart';
import 'package:dev_test/test.dart';

// To make tests less verbose...
class Lock extends SynchronizedLockImpl {}

void main() {
  group('synchronized_impl', () {
    test('makeSynchronizedLock', () async {
      expect(synchronizedLocks, isEmpty);
      SynchronizedLockImpl lockImpl = makeSynchronizedLock("test");
      expect(lockImpl.monitor, "test");
      expect(synchronizedLocks, hasLength(1));
      // clear for next tests
      synchronizedLocks.clear();
    });
    test('synchronizedLocks', () async {
      expect(synchronizedLocks, isEmpty);

      Future future = synchronized("test", () {
        sleep(1);
      });
      expect(synchronizedLocks, hasLength(1));
      await future;
      expect(synchronizedLocks, isEmpty);
    });

    test('synchronizedLocks_2', () async {
      expect(synchronizedLocks, isEmpty);

      synchronized("test", () {
        sleep(1);
      });
      Future future = synchronized("test", () {
        sleep(1);
      });
      expect(synchronizedLocks, hasLength(1));
      await future;
      expect(synchronizedLocks, isEmpty);
    });

    test('synchronizedLocks_inner', () async {
      expect(synchronizedLocks, isEmpty);

      Completer beforeInnerCompleter = new Completer.sync();
      Future future = synchronized("test", () async {
        sleep(1);
        beforeInnerCompleter.complete();
        await synchronized("test", () {
          sleep(1);
        });
      });
      expect(synchronizedLocks, hasLength(1));
      await beforeInnerCompleter.future;
      expect(synchronizedLocks, hasLength(1));
      await future;
      expect(synchronizedLocks, isEmpty);
    });

    group('two_locks', () {
      test('inZone',() {
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
      });
    });

  });
}
