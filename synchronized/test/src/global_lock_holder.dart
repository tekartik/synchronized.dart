import 'dart:convert';
import 'dart:io';

import 'package:synchronized/global_lock.dart';
import 'package:synchronized/src/global_lock_io.dart';

/// Holds the lock named by the first argument until `release` is read on
/// stdin (used by `global_lock_io_test.dart` as another process).
///
/// Optional arguments: the lock folder, the heartbeat in milliseconds, and
/// `exit` to return from main without releasing the lock.
Future<void> main(List<String> arguments) async {
  final name = arguments.first;
  final lock = arguments.length > 1
      ? GlobalLockIo(
          name,
          dir: arguments[1],
          heartbeatInterval: Duration(milliseconds: int.parse(arguments[2])),
        )
      : GlobalLock(name);
  final handle = await lock.acquire();
  stdout.writeln('acquired');
  if (arguments.length > 3 && arguments[3] == 'exit') {
    return;
  }
  await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .firstWhere((line) => line == 'release');
  await handle.release();
  stdout.writeln('released');
}
