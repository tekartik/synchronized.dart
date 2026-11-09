import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'global_lock.dart';

/// A [GlobalLock] shared by the isolates and processes of the machine (of
/// the same user).
GlobalLock newGlobalLock(String name) => GlobalLockIo(name);

/// How often a holder touches its lock file.
const globalLockHeartbeatInterval = Duration(seconds: 1);

/// A lock file a waiter saw untouched for this long (on the waiter's own
/// clock) is taken over: its holder process died (or its heartbeat isolate is
/// frozen).
const globalLockStaleTimeout = Duration(seconds: 10);

/// The longest wait between two tries.
const _maxRetryDelay = Duration(milliseconds: 200);

/// After this many failures to create a lock file that does not exist (no
/// permission), the error is thrown.
const _maxCreateErrors = 50;

final _random = Random();

String _sanitize(String text) =>
    text.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

/// The folder of the lock files: `/tmp/synchronized_global_lock_<user>` on
/// Linux and macOS (whatever `TMPDIR`, which may differ between the
/// processes of the user), `synchronized_global_lock` in the system temp
/// folder elsewhere (Windows, mobile).
String globalLockDefaultDir() {
  if (Platform.isLinux || Platform.isMacOS) {
    final env = Platform.environment;
    final user = _sanitize(env['USER'] ?? env['LOGNAME'] ?? '');
    return '/tmp/synchronized_global_lock${user.isEmpty ? '' : '_$user'}';
  }
  return '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'synchronized_global_lock';
}

/// The lock file name of [name]: [name] made safe for a file name (64
/// characters at most) and an FNV-1a hash of its utf8 bytes (two names never
/// share a file once made safe).
String globalLockFileName(String name) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(name)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  var safe = _sanitize(name);
  if (safe.length > 64) {
    safe = safe.substring(0, 64);
  }
  return '${safe}_${hash.toRadixString(16).padLeft(8, '0')}.lock';
}

/// A [GlobalLock] held by an exclusively created lock file, touched every
/// [heartbeatInterval] by a heartbeat isolate, which deletes it when the
/// holder isolate exits without releasing it.
///
/// A lock file that a waiter saw untouched for [staleTimeout] is deleted by
/// that waiter (one at a time, holding the `.break` file next to it), so a
/// holder process that died (crash, kill) blocks the others for about
/// [staleTimeout]. The delay is timed on the waiter's own (monotonic)
/// stopwatch, never by comparing the file time with the wall clock: a clock
/// change or a suspended machine cannot make a live lock look stale. Nothing
/// outside the lock folder can hold the lock.
class GlobalLockIo with GlobalLockMixin {
  /// Creates the lock [name], its file in [dir] ([globalLockDefaultDir] by
  /// default).
  GlobalLockIo(
    this.name, {
    String? dir,
    this.heartbeatInterval = globalLockHeartbeatInterval,
    this.staleTimeout = globalLockStaleTimeout,
  }) : path =
           '${dir ?? globalLockDefaultDir()}${Platform.pathSeparator}'
           '${globalLockFileName(name)}';

  @override
  final String name;

  /// The lock file path.
  final String path;

  /// How often the holder touches the lock file.
  final Duration heartbeatInterval;

  /// A lock file a waiter saw untouched for this long is taken over.
  final Duration staleTimeout;

  @override
  Future<GlobalLockHandle> acquire({Duration? timeout}) async {
    final stopwatch = Stopwatch()..start();
    final file = File(path);
    var delay = const Duration(milliseconds: 10);
    var createErrors = 0;
    final lockWatch = _StaleWatch(staleTimeout);
    final breakerWatch = _StaleWatch(staleTimeout);
    while (true) {
      try {
        await file.create(exclusive: true);
        return await _GlobalLockIoHandle.start(file, heartbeatInterval);
      } on FileSystemException {
        if (!file.existsSync()) {
          if (!file.parent.existsSync()) {
            await file.parent.create(recursive: true);
            continue;
          }
          // Being deleted (Windows) or no permission.
          if (++createErrors > _maxCreateErrors) {
            rethrow;
          }
        } else if (await _breakIfStale(file, lockWatch, breakerWatch)) {
          continue;
        }
      }
      var wait = delay;
      if (timeout != null) {
        final remaining = timeout - stopwatch.elapsed;
        if (remaining <= Duration.zero) {
          throw globalLockTimeoutException(
            name,
            timeout,
            details: _holderDetails(file),
          );
        }
        if (remaining < wait) {
          wait = remaining;
        }
      }
      await Future<void>.delayed(wait);
      delay = delay * 2;
      if (delay > _maxRetryDelay) {
        delay = _maxRetryDelay;
      }
    }
  }

  /// Deletes the lock [file] when stale ([lockWatch]), holding the `.break`
  /// file (so that a waiter never deletes the lock file another waiter just
  /// created). Returns true when deleted.
  Future<bool> _breakIfStale(
    File file,
    _StaleWatch lockWatch,
    _StaleWatch breakerWatch,
  ) async {
    if (!lockWatch.isStale(file)) {
      return false;
    }
    final breaker = File('${file.path}.break');
    try {
      await breaker.create(exclusive: true);
    } on FileSystemException {
      // Another waiter breaking it, or a waiter that died doing it.
      if (breakerWatch.isStale(breaker)) {
        try {
          await breaker.delete();
        } catch (_) {}
      }
      return false;
    }
    try {
      // Still the file seen stale (not replaced meanwhile).
      if (lockWatch.isStale(file)) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      try {
        await breaker.delete();
      } catch (_) {}
    }
  }

  /// The holder (pid) and the lock file, for a timeout message.
  String _holderDetails(File file) {
    var holder = 'unknown';
    try {
      final content = file.readAsStringSync().split(' ');
      if (content.first.isNotEmpty) {
        holder = 'pid ${content.first}';
      }
    } catch (_) {}
    return 'held by $holder (${file.path})';
  }
}

/// The modification time of a file as seen by a waiter: stale once unchanged
/// for [timeout] on the waiter's own stopwatch (monotonic), whatever the wall
/// clock does (clock step, suspended machine), so that the file time is only
/// compared with itself.
class _StaleWatch {
  _StaleWatch(this.timeout);

  /// The stale delay.
  final Duration timeout;

  /// The last modification time seen, null when the file was not seen.
  DateTime? _modified;

  /// Time since [_modified] was first seen.
  final _unchanged = Stopwatch();

  /// True when [file] exists and its modification time did not change for
  /// [timeout] since this watch first saw it.
  bool isStale(File file) {
    final stat = file.statSync();
    if (stat.type == FileSystemEntityType.notFound) {
      _modified = null;
      return false;
    }
    if (stat.modified != _modified) {
      _modified = stat.modified;
      _unchanged
        ..reset()
        ..start();
      return false;
    }
    return _unchanged.elapsed >= timeout;
  }
}

/// Deletes the lock [file] if it still holds [token] (not taken over).
void _deleteIfOwned(File file, String token) {
  try {
    if (file.readAsStringSync() == token) {
      file.deleteSync();
    }
  } catch (_) {}
}

/// Messages of the heartbeat isolate.
const _heartbeatStop = 'stop';
const _ownerExited = 'exited';
const _ownerAlive = 'alive';

/// Without an answer to its ping in this time, the owner died before the
/// heartbeat listened to its exit.
const _ownerPingTimeout = Duration(seconds: 5);

/// The heartbeat isolate: touches the lock file every interval until the
/// owner releases the lock ([_heartbeatStop], the owner deletes the file) or
/// exits without releasing it (the file is deleted here).
///
/// Another isolate, so the lock stays held while the event loop of the owner
/// is blocked (synchronous work, `Process.runSync`). It does not keep the
/// process alive: a process exiting without releasing leaves a lock file
/// taken over once stale.
void _heartbeatMain(
  (String path, String token, Duration interval, SendPort owner, SendPort) args,
) {
  final (path, token, interval, ownerControlPort, ready) = args;
  final file = File(path);
  final port = ReceivePort();
  final heartbeat = Timer.periodic(interval, (_) {
    try {
      file.setLastModifiedSync(DateTime.now());
    } catch (_) {}
  });
  Timer? pingTimeout;
  var stopped = false;
  void stop({required bool deleteFile}) {
    if (stopped) {
      return;
    }
    stopped = true;
    heartbeat.cancel();
    pingTimeout?.cancel();
    port.close();
    if (deleteFile) {
      _deleteIfOwned(file, token);
    }
  }

  final owner = Isolate(ownerControlPort);
  owner.addOnExitListener(port.sendPort, response: _ownerExited);
  // An owner dead before the listener was added sends no exit message, nor
  // an answer.
  owner.ping(port.sendPort, response: _ownerAlive, priority: Isolate.immediate);
  pingTimeout = Timer(_ownerPingTimeout, () => stop(deleteFile: true));
  port.listen((message) {
    switch (message) {
      case _ownerAlive:
        pingTimeout?.cancel();
      case _ownerExited:
        stop(deleteFile: true);
      case _heartbeatStop:
        stop(deleteFile: false);
    }
  });
  ready.send(port.sendPort);
}

class _GlobalLockIoHandle implements GlobalLockHandle {
  _GlobalLockIoHandle._(this._file, this._token, this._heartbeat);

  /// Writes the owner (pid and a token) in [file], just created, and starts
  /// the heartbeat isolate.
  static Future<_GlobalLockIoHandle> start(File file, Duration interval) async {
    final token = '$pid ${_random.nextInt(1 << 31)}${_random.nextInt(1 << 31)}';
    try {
      await file.writeAsString(token, flush: true);
    } catch (_) {}
    final ready = ReceivePort();
    try {
      await Isolate.spawn(_heartbeatMain, (
        file.path,
        token,
        interval,
        Isolate.current.controlPort,
        ready.sendPort,
      ), debugName: 'GlobalLock heartbeat');
      final heartbeat = await ready.first as SendPort;
      return _GlobalLockIoHandle._(file, token, heartbeat);
    } catch (_) {
      ready.close();
      _deleteIfOwned(file, token);
      rethrow;
    }
  }

  final File _file;
  final String _token;
  SendPort? _heartbeat;

  @override
  Future<void> release() async {
    final heartbeat = _heartbeat;
    if (heartbeat == null) {
      return;
    }
    _heartbeat = null;
    heartbeat.send(_heartbeatStop);
    // Taken over (owner and heartbeat frozen past the stale timeout): the
    // file of another.
    _deleteIfOwned(_file, _token);
  }
}
