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
  });
}
