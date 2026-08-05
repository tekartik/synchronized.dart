// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:synchronized/extension.dart';
import 'package:synchronized/src/utils.dart';
import 'package:test/test.dart';

class MyClass {
  MyClass(this.text);

  final String text;

  /// Perform a long action that won't be called more than once at a time.
  Future<void> performClassAction() {
    // Lock at the class level
    return runtimeType.synchronized(() async {
      // ...uninterrupted action
    });
  }

  /// Perform a long action that won't be called more than once at a time.
  Future<void> performAction() {
    // Lock at the class level
    return synchronized(() async {
      // ...uninterrupted action
    });
  }

  @override
  int get hashCode => text.hashCode;

  @override
  bool operator ==(other) {
    if (other is MyClass) {
      return (other.text == text);
    }
    return false;
  }
}

void main() {
  group('extension', () {
    test('order', () async {
      const lock = 'test';
      final list = <int>[];
      final future1 = lock.synchronized(() async {
        list.add(1);
      });
      final future2 = ('${'te'}${'st'}').synchronized(() async {
        await sleep(10);
        list.add(2);
        return 'text';
      });
      final future3 = lock.synchronized(() {
        list.add(3);
        return 1234;
      });
      expect(list, [1]);
      await Future.wait([future1, future2, future3]);
      expect(await future1, isNull);
      expect(await future2, 'text');
      expect(await future3, 1234);
      expect(list, [1, 2, 3]);
    });

    test('non-reentrant', () async {
      Object? exception;
      await 'non-reentrant'.synchronized(() async {
        try {
          await 'non-reentrant'.synchronized(
            () {},
            timeout: const Duration(seconds: 1),
          );
        } catch (e) {
          exception = e;
        }
      });
      expect(exception, const TypeMatcher<TimeoutException>());
    });

    test('Myclass non-reentrant', () async {
      await MyClass('non-reentrant').synchronized(() async {
        await MyClass(
          'non-reentrant-distinct',
        ).synchronized(() {}, timeout: const Duration(seconds: 1));
      });
    });

    group('lock keying contract', () {
      // The lock cache is a plain Map, so it keys on ==/hashCode rather than
      // identity. Nothing else pins this, which is how the dartdoc managed to
      // claim the opposite for years.
      test('equal but distinct objects share a lock', () async {
        final a = MyClass('keying');
        final b = MyClass('keying');
        expect(identical(a, b), isFalse);
        expect(a == b, isTrue);

        Object? exception;
        await a.synchronized(() async {
          try {
            await b.synchronized(
              () {},
              timeout: const Duration(milliseconds: 100),
            );
          } catch (e) {
            exception = e;
          }
        });
        expect(
          exception,
          const TypeMatcher<TimeoutException>(),
          reason: 'equal objects must contend for the same lock',
        );
      });

      test('unequal objects do not contend', () async {
        final a = MyClass('keying-a');
        final b = MyClass('keying-b');
        expect(a == b, isFalse);

        var ran = false;
        await a.synchronized(() async {
          await b.synchronized(() {
            ran = true;
          }, timeout: const Duration(seconds: 1));
        });
        expect(ran, isTrue);
      });
    });

    test('doc', () async {
      var myObject = MyClass('doc');

      // ignore: unawaited_futures
      myObject.synchronized(() async {
        // ...uninterrupted action
      });
    });
  });
}
