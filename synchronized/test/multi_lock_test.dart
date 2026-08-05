// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:synchronized/synchronized.dart';
import 'package:test/test.dart';

import 'common_lock_test_.dart' as lock_test;
import 'lock_factory.dart';

void main() {
  final lockFactory = MultiLockFactory();
  group('MultiLock', () {
    // Common tests
    lock_test.lockMain(lockFactory);

    test('multi', () async {
      var lock1 = Lock();
      var lock2 = Lock(reentrant: true);
      var multiLock = MultiLock(locks: [lock1, lock2]);
      var completer = Completer<void>();
      var future = lock1.synchronized(() async {
        expect(multiLock.inLock, isFalse);
        expect(multiLock.locked, isFalse);
        expect(multiLock.canLock, isFalse);
        await completer.future;
      });
      expect(multiLock.inLock, isFalse);
      expect(multiLock.locked, isFalse);
      expect(multiLock.canLock, isFalse);

      // Expect a time out exception
      var hasTimeoutException = false;
      try {
        await multiLock.synchronized(
          () {},
          timeout: const Duration(milliseconds: 100),
        );
        fail('should fail');
      } on TimeoutException catch (_) {
        // Timeout exception expected
        hasTimeoutException = true;
      }
      expect(hasTimeoutException, isTrue);
      completer.complete();
      completer = Completer<void>();

      await future;
      expect(multiLock.inLock, isFalse);
      expect(multiLock.locked, isFalse);
      expect(multiLock.canLock, isTrue);
      future = multiLock.synchronized(() async {
        expect(multiLock.inLock, isTrue);
        expect(multiLock.locked, isTrue);
        expect(multiLock.canLock, isFalse);
        expect(lock1.inLock, isTrue);
        expect(lock1.locked, isTrue);
        expect(lock1.canLock, isFalse);
        expect(lock2.inLock, isTrue);
        expect(lock2.locked, isTrue);
        expect(lock2.canLock, isTrue);
        await completer.future;
      });
      expect(multiLock.inLock, isFalse); // Cause using a reentrant lock
      expect(multiLock.locked, isTrue);
      expect(multiLock.canLock, isFalse);
      expect(lock1.inLock, isTrue);
      expect(lock1.locked, isTrue);
      expect(lock1.canLock, isFalse);
      expect(lock2.inLock, isFalse);
      expect(lock2.locked, isTrue);
      expect(lock2.canLock, isFalse);
      hasTimeoutException = false;
      try {
        await lock1.synchronized(
          () {},
          timeout: const Duration(milliseconds: 100),
        );
        fail('should fail');
      } on TimeoutException catch (_) {
        // Timeout exception expected
        hasTimeoutException = true;
      }
      expect(hasTimeoutException, isTrue);
      hasTimeoutException = false;
      try {
        await lock2.synchronized(
          () {},
          timeout: const Duration(milliseconds: 100),
        );
        fail('should fail');
      } on TimeoutException catch (_) {
        // Timeout exception expected
        hasTimeoutException = true;
      }
      expect(hasTimeoutException, isTrue);

      completer.complete();
      await future;
      await lock2.synchronized(() async {
        expect(multiLock.inLock, isFalse);
        expect(multiLock.locked, isFalse);
        expect(multiLock.canLock, isTrue);

        await lock1.synchronized(() async {
          expect(
            multiLock.inLock,
            isTrue,
          ); // Not what we would expect but ok...
          expect(multiLock.locked, isTrue);
          expect(multiLock.canLock, isFalse);
        });
      });
    });

    group('lock set is captured at construction', () {
      test('serialises over a lazy Iterable', () async {
        var built = 0;
        final inner = [Lock(), Lock()];
        // A lazy Iterable: re-iterating it rebuilds the sequence. The
        // MultiLock must not depend on that happening to be idempotent.
        Iterable<Lock> lazy() sync* {
          built++;
          yield* inner;
        }

        final multiLock = MultiLock(locks: lazy());
        expect(built, 1, reason: 'copied once, at construction');

        final order = <String>[];
        final first = multiLock.synchronized(() async {
          order.add('a-start');
          await sleep(20);
          order.add('a-end');
        });
        final second = multiLock.synchronized(() async {
          order.add('b-start');
          await sleep(1);
          order.add('b-end');
        });
        await Future.wait([first, second]);

        expect(order, ['a-start', 'a-end', 'b-start', 'b-end']);
        expect(built, 1, reason: 'never re-iterated after construction');
      });

      test('rebuilt elements would lose exclusion without the copy', () async {
        // Guards the actual failure mode: an Iterable yielding fresh locks.
        // The copy pins the first batch, so exclusion still holds.
        Iterable<Lock> fresh() sync* {
          yield Lock();
        }

        final multiLock = MultiLock(locks: fresh());
        final order = <String>[];
        final first = multiLock.synchronized(() async {
          order.add('a-start');
          await sleep(20);
          order.add('a-end');
        });
        final second = multiLock.synchronized(() async {
          order.add('b-start');
        });
        await Future.wait([first, second]);
        expect(order, ['a-start', 'a-end', 'b-start']);
      });

      test('mutating the source list does not change the lock set', () async {
        final held = Lock();
        final source = [held];
        final multiLock = MultiLock(locks: source);

        source.add(Lock());
        source.removeAt(0);

        final completer = Completer<void>();
        final future = held.synchronized(() => completer.future);
        // Still bound to `held`, not to whatever `source` now contains.
        expect(multiLock.canLock, isFalse);
        completer.complete();
        await future;
        expect(multiLock.canLock, isTrue);
      });
    });
  });
}
