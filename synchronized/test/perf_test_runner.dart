// Manual benchmark. `dart test` does not pick this file up -- the name does
// not end in `_test.dart`. Run it explicitly:
//
//     dart test test/perf_test_runner.dart
//
// The same body doubles as a small smoke check inside the common lock suite,
// which calls [lockPerfTest] with a much lower operation count.

// ignore_for_file: avoid_print

import 'package:synchronized/synchronized.dart';
import 'package:test/test.dart';

import 'lock_factory.dart';

/// Operation count for a real benchmark run. The in-suite smoke check uses a
/// far smaller one.
const benchmarkOperationCount = 500000;

void main() {
  group('BasicLock', () {
    lockPerfTest(BasicLockFactory(), operationCount: benchmarkOperationCount);
  });
  group('ReentrantLock', () {
    lockPerfTest(
      ReentrantLockFactory(),
      operationCount: benchmarkOperationCount,
    );
  });
  group('MultiLock', () {
    lockPerfTest(MultiLockFactory(), operationCount: benchmarkOperationCount);
  });
}

/// Times [operationCount] increments four ways -- bare loop, bare `await`,
/// queued `synchronized`, and awaited async `synchronized` -- and prints the
/// elapsed time of each. Also asserts the lock drains: after queueing that
/// many blocks it must report unlocked again.
void lockPerfTest(LockFactory factory, {required int operationCount}) {
  Lock newLock() => factory.newLock();

  test('$operationCount operations', () async {
    final count = operationCount;
    int j;

    final sw1 = Stopwatch();
    j = 0;
    sw1.start();
    for (var i = 0; i < count; i++) {
      j += i;
    }
    sw1.stop();
    expect(j, count * (count - 1) / 2);

    final sw2 = Stopwatch();
    j = 0;
    sw2.start();
    for (var i = 0; i < count; i++) {
      await () async {
        j += i;
      }();
    }
    sw2.stop();
    expect(j, count * (count - 1) / 2);

    var lock = newLock();
    final sw3 = Stopwatch();
    j = 0;
    sw3.start();
    for (var i = 0; i < count; i++) {
      // ignore: unawaited_futures
      lock.synchronized(() {
        j += i;
      });
    }
    // final wait
    await lock.synchronized(() => {});
    expect(lock.locked, isFalse);
    sw3.stop();
    expect(j, count * (count - 1) / 2);

    final sw4 = Stopwatch();
    j = 0;
    sw4.start();
    for (var i = 0; i < count; i++) {
      await lock.synchronized(() async {
        await Future<void>.value();
        j += i;
      });
    }
    // final wait
    expect(lock.locked, isFalse);
    sw4.stop();
    expect(j, count * (count - 1) / 2);

    print('  none ${sw1.elapsed}');
    print(' await ${sw2.elapsed}');
    print(' syncd ${sw3.elapsed}');
    print('asyncd ${sw4.elapsed}');
  });
}
