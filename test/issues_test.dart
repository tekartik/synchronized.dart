// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dev_test/test.dart';
import 'package:synchronized/src/utils.dart';
import 'package:synchronized/synchronized.dart' hide SynchronizedLock;

void main() {
  group('issues', () {
    // https://github.com/tekartik/synchronized.dart/issues/1
    test('issue_1', () async {
      var value = '';

      Future outer1 = synchronized('test', () async {
        expect(value, equals(''));
        value = 'outer1';

        await sleep(20);

        await synchronized('test', () async {
          await sleep(30);
          expect(value, equals('outer1'));
          value = 'inner1';
        });
      });

      Future outer2 = synchronized('test', () async {
        await sleep(30);
        expect(value, equals('inner1'));
        value = 'outer2';
      });

      Future outer3 = sleep(30).whenComplete(() {
        return synchronized('test', () async {
          expect(value, equals('outer2'));
          value = 'outer3';
        });
      });

      await Future.wait([outer1, outer2, outer3]);

      expect(value, equals('outer3'));
    });
  });
}
