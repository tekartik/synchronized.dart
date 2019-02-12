// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:synchronized/src/basic_lock.dart';
import 'package:synchronized/src/reentrant_lock.dart';
import 'package:synchronized/src/utils.dart';
import 'package:synchronized/synchronized.dart' as common;
import 'package:test/test.dart';

// To make tests less verbose...
class _Lock extends ReentrantLock {
  _Lock() : super();
}

void main() {
  group('synchronized_impl', () {
    group('BasicLock', () {
      test('type', () {
        var lock = common.Lock();
        expect(lock, const TypeMatcher<BasicLock>());
      });
      test('toString', () {
        var lock = common.Lock();
        expect("$lock", startsWith("Lock["));
        expect("$lock", endsWith("]"));
      });
    });

    group('ReentrantLock', () {
      test('type', () {
        var lock = common.Lock(reentrant: true);
        expect(lock, const TypeMatcher<ReentrantLock>());
      });

      test('toString', () {
        var lock = common.Lock(reentrant: true);
        expect("$lock", startsWith("ReentrantLock["));
        expect("$lock", endsWith("]"));
      });

      group('locked', () {
        test('inner', () async {
          _Lock lock = _Lock();
          Completer completer = Completer();
          Completer innerCompleter = Completer();
          Future future = lock.synchronized(() async {
            // don't wait here
            // ignore: unawaited_futures
            lock.synchronized(() async {
              await sleep(1);
              await innerCompleter.future;
            });
            await completer.future;
          });
          expect(lock.locked, isTrue);
          completer.complete();
          try {
            await lock.synchronized(null, timeout: Duration(milliseconds: 100));
            fail('should fail');
          } on TimeoutException catch (_) {}
          expect(lock.locked, isTrue);
          innerCompleter.complete();
          await future;
          expect(lock.locked, isFalse);
        });
      });

      group('inLock', () {
        test('two_locks', () async {
          _Lock lock1 = _Lock();
          _Lock lock2 = _Lock();
          Completer completer = Completer();
          Future future = lock1.synchronized(() async {
            expect(lock1.inLock, isTrue);
            expect(lock2.inLock, isFalse);
            await completer.future;
          });
          expect(lock1.inLock, isFalse);
          completer.complete();
          await future;
        });

        test('inner', () async {
          _Lock lock = _Lock();
          Future future = lock.synchronized(() async {
            expect(lock.inLock, isTrue);

            expect(lock.innerFutures.length, 0);

            // don't wait here
            // ignore: unawaited_futures
            await lock.synchronized(() async {
              expect(lock.innerFutures.length, 1);
              expect(lock.inLock, isTrue);
              await sleep(10);
              expect(lock.inLock, isTrue);
              expect(lock.innerFutures.length, 1);
            });
            expect(lock.innerFutures.length, 0);
          });
          expect(lock.inLock, isFalse);
          await future;
          expect(lock.inLock, isFalse);
        });

        test('inner_vs_outer', () async {
          List<int> list = [];
          _Lock lock = _Lock();
          Future future = lock.synchronized(() async {
            await sleep(10);
            // don't wait here
            // ignore: unawaited_futures
            lock.synchronized(() async {
              await sleep(20);
              list.add(1);
            });
          });
          expect(lock.inLock, isFalse);
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
