// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:synchronized/extension.dart';
import 'package:synchronized/src/basic_lock.dart';
import 'package:synchronized/src/extension_impl.dart';
import 'package:test/test.dart';

void main() {
  group('extension_impl', () {
    test('cache', () async {
      expect(cacheLocks, isEmpty);
      await 'test'.synchronized(() {
        expect(cacheLocks['test'], const TypeMatcher<BasicLock>());
      });
      expect(cacheLocks, isEmpty);
    });

    test('cache cleaned after a call with a timeout that waited', () async {
      var monitor = Object();
      var first = monitor.synchronized(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      // Waits for the first one, then gets the lock.
      var second = monitor.synchronized(
        () => 2,
        timeout: const Duration(seconds: 10),
      );
      await first;
      expect(await second, 2);
      expect(cacheLocks, isEmpty);
    });

    test('cache cleaned after a call that timed out', () async {
      var monitor = Object();
      var first = monitor.synchronized(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await expectLater(
        monitor.synchronized(() {}, timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      await first;
      expect(cacheLocks, isEmpty);
    });

    test('random calls, timeouts and pauses', () async {
      Future<void> pause(Random random) async {
        switch (random.nextInt(4)) {
          case 0:
            return;
          case 1:
            await null;
          case 2:
            await Future<void>.microtask(() {});
          default:
            await Future<void>.delayed(
              Duration(milliseconds: random.nextInt(3)),
            );
        }
      }

      for (var seed = 0; seed < 100; seed++) {
        var random = Random(seed);
        const monitor = 'random';
        var running = 0;
        var maxRunning = 0;
        await Future.wait(
          List.generate(12, (_) async {
            await pause(random);
            try {
              await monitor.synchronized(
                () async {
                  running++;
                  maxRunning = max(maxRunning, running);
                  await pause(random);
                  running--;
                },
                timeout: random.nextBool()
                    ? Duration(milliseconds: random.nextInt(3))
                    : null,
              );
            } on TimeoutException catch (_) {}
          }),
        );
        expect(maxRunning, 1, reason: 'seed $seed');
        expect(cacheLocks, isEmpty, reason: 'seed $seed');
      }
    });
  });
}
