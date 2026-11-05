@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:synchronized/global_lock.dart';
import 'package:synchronized/src/global_lock_io.dart';
import 'package:test/test.dart';

import 'src/global_lock_test_utils.dart';

/// Long enough for a lock released by another isolate or process.
const _acquireTimeout = Duration(seconds: 10);

/// Short timings, for the take over tests.
const _heartbeat = Duration(milliseconds: 100);
const _stale = Duration(seconds: 1);

/// Try to acquire [name] in another isolate within [timeout]: 'acquired'
/// (then released) or 'timeout'.
Future<String> _acquireInIsolate(String name, Duration timeout) =>
    Isolate.run(() async {
      try {
        var handle = await GlobalLock(name).acquire(timeout: timeout);
        await handle.release();
        return 'acquired';
      } on TimeoutException {
        return 'timeout';
      }
    });

/// Another process holding the lock [name] (in [dir] with a short heartbeat
/// when set).
class _Holder {
  _Holder._(this.process)
    : _lines = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );

  final Process process;
  final StreamIterator<String> _lines;

  static Future<_Holder> start(String name, {String? dir}) async {
    var process = await Process.start(Platform.resolvedExecutable, [
      'test/src/global_lock_holder.dart',
      name,
      if (dir != null) ...[dir, '${_heartbeat.inMilliseconds}'],
    ]);
    unawaited(stderr.addStream(process.stderr));
    var holder = _Holder._(process);
    await holder.expectLine('acquired');
    return holder;
  }

  Future<void> expectLine(String expected) async {
    expect(
      await _lines.moveNext().timeout(const Duration(seconds: 60)),
      isTrue,
    );
    expect(_lines.current, expected);
  }
}

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('synchronized_lock_test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  /// A lock in [dir] with the short timings.
  GlobalLockIo newLock(String name) => GlobalLockIo(
    name,
    dir: dir.path,
    heartbeatInterval: _heartbeat,
    staleTimeout: _stale,
  );

  group('GlobalLock io', () {
    test('file name', () {
      expect(globalLockFileName('test'), 'test_afd071e5.lock');
      expect(globalLockFileName(''), '_811c9dc5.lock');
      expect(globalLockFileName('a/b c'), startsWith('a_b_c_'));
      expect(globalLockFileName('a/b'), isNot(globalLockFileName('a_b')));
      expect(globalLockFileName('é'), isNot(globalLockFileName('e')));
      expect(
        globalLockFileName('x' * 100).length,
        64 + '_12345678.lock'.length,
      );
    });

    test('default dir', () {
      var lock = GlobalLock('test') as GlobalLockIo;
      expect(lock.path, startsWith(globalLockDefaultDir()));
      expect(lock.path, endsWith(globalLockFileName('test')));
      expect(lock.heartbeatInterval, const Duration(seconds: 1));
      expect(lock.staleTimeout, const Duration(seconds: 10));
      if (Platform.isLinux || Platform.isMacOS) {
        expect(
          globalLockDefaultDir(),
          startsWith('/tmp/synchronized_global_lock'),
        );
      }
    });

    test('missing folder created', () async {
      var lock = GlobalLockIo('test', dir: '${dir.path}/sub/folder');
      await (await lock.acquire(timeout: _acquireTimeout)).release();
      expect(File(lock.path).existsSync(), isFalse);
    });

    test('lock file while held', () async {
      var lock = newLock('test');
      var handle = await lock.acquire();
      expect(File(lock.path).readAsStringSync(), startsWith('$pid '));
      await handle.release();
      expect(File(lock.path).existsSync(), isFalse);
    });

    test('other isolate', () async {
      var name = newGlobalLockName();
      var handle = await GlobalLock(name).acquire();
      expect(
        await _acquireInIsolate(name, const Duration(milliseconds: 100)),
        'timeout',
      );
      await handle.release();
      expect(await _acquireInIsolate(name, _acquireTimeout), 'acquired');
    });

    test('isolates serialized', () async {
      var path = dir.path;
      var counter = File('${dir.path}/counter')..writeAsStringSync('0');
      await Future.wait(
        List.generate(
          4,
          (_) => Isolate.run(() async {
            var lock = GlobalLockIo('counter', dir: path);
            var file = File('$path/counter');
            for (var i = 0; i < 10; i++) {
              await lock.synchronized(() async {
                var value = int.parse(file.readAsStringSync());
                // Lets another holder interleave if not exclusive.
                await Future<void>.delayed(const Duration(milliseconds: 5));
                file.writeAsStringSync('${value + 1}');
              }, timeout: const Duration(seconds: 60));
            }
          }),
        ),
      );
      expect(counter.readAsStringSync(), '40');
    });

    test('timeout message', () async {
      var lock = newLock('test');
      var handle = await lock.acquire();
      try {
        await newLock('test').acquire(timeout: Duration.zero);
        fail('should time out');
      } on TimeoutException catch (e) {
        expect(e.message, contains('GlobalLock(test) not acquired'));
        expect(e.message, contains('held by pid $pid (${lock.path})'));
        expect(e.duration, Duration.zero);
      } finally {
        await handle.release();
      }
    });

    test('heartbeat keeps it held', () async {
      var handle = await newLock('test').acquire();
      // Three times the stale timeout.
      await expectLater(
        newLock('test').acquire(timeout: _stale * 3),
        throwsA(isA<TimeoutException>()),
      );
      await handle.release();
    });

    test('stale file taken over', () async {
      var lock = newLock('test');
      File(lock.path)
        ..writeAsStringSync('1 dead')
        ..setLastModifiedSync(DateTime.now().subtract(_stale * 2));
      await (await lock.acquire(timeout: Duration.zero)).release();
    });

    test('stale breaker taken over', () async {
      var lock = newLock('test');
      var old = DateTime.now().subtract(_stale * 2);
      File(lock.path)
        ..writeAsStringSync('1 dead')
        ..setLastModifiedSync(old);
      File('${lock.path}.break')
        ..writeAsStringSync('')
        ..setLastModifiedSync(old);
      await (await lock.acquire(timeout: _acquireTimeout)).release();
      expect(File('${lock.path}.break').existsSync(), isFalse);
    });

    test('release keeps the file of another holder', () async {
      var lock = newLock('test');
      var handle = await lock.acquire();
      // Taken over while frozen.
      File(lock.path).writeAsStringSync('1 other');
      await handle.release();
      expect(File(lock.path).readAsStringSync(), '1 other');
    });

    test('killed isolate taken over', () async {
      var path = dir.path;
      var ready = ReceivePort();
      var isolate = await Isolate.spawn((SendPort sendPort) async {
        await GlobalLockIo(
          'test',
          dir: path,
          heartbeatInterval: _heartbeat,
        ).acquire();
        sendPort.send(true);
      }, ready.sendPort);
      await ready.first;
      await expectLater(
        newLock('test').acquire(timeout: Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
      isolate.kill(priority: Isolate.immediate);
      await (await newLock('test').acquire(timeout: _acquireTimeout)).release();
    });

    test('other process', () async {
      var name = newGlobalLockName();
      var holder = await _Holder.start(name);
      await expectLater(
        GlobalLock(name).acquire(timeout: const Duration(milliseconds: 200)),
        throwsA(isA<TimeoutException>()),
      );
      holder.process.stdin.writeln('release');
      await holder.expectLine('released');
      expect(await holder.process.exitCode, 0);
      var handle = await GlobalLock(name).acquire(timeout: _acquireTimeout);
      await handle.release();
    });

    test('killed process taken over', () async {
      var holder = await _Holder.start('test', dir: dir.path);
      await expectLater(
        newLock('test').acquire(timeout: Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
      holder.process.kill(ProcessSignal.sigkill);
      await holder.process.exitCode;
      var handle = await newLock('test').acquire(timeout: _acquireTimeout);
      await handle.release();
    });
  });
}
