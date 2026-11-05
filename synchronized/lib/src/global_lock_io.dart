import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'global_lock.dart';

/// A [GlobalLock] shared by the isolates and processes of the machine (of
/// the same user).
GlobalLock newGlobalLock(String name) => GlobalLockIo(name);

/// How often a holder touches its lock file.
const globalLockHeartbeatInterval = Duration(seconds: 1);

/// A lock file not touched for this long is taken over: its holder died
/// (process or isolate) or its event loop is frozen.
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

/// A [GlobalLock] held by an exclusively created lock file, touched by its
/// holder every [heartbeatInterval].
///
/// A lock file not touched for [staleTimeout] is deleted by a waiter (one at
/// a time, holding the `.break` file next to it), so a holder that died
/// (crash, kill, isolate killed) blocks the others for [staleTimeout] at
/// most. Nothing outside the lock folder can hold the lock.
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

  /// A lock file not touched for this long is taken over.
  final Duration staleTimeout;

  @override
  Future<GlobalLockHandle> acquire({Duration? timeout}) async {
    final stopwatch = Stopwatch()..start();
    final file = File(path);
    var delay = const Duration(milliseconds: 10);
    var createErrors = 0;
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
        } else if (await _breakIfStale(file)) {
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

  /// True when [file] exists and was not touched for [staleTimeout].
  bool _isStale(File file) {
    final stat = file.statSync();
    return stat.type != FileSystemEntityType.notFound &&
        DateTime.now().difference(stat.modified) > staleTimeout;
  }

  /// Deletes the lock [file] when stale, holding the `.break` file (so that
  /// a waiter never deletes the lock file another waiter just created).
  /// Returns true when deleted.
  Future<bool> _breakIfStale(File file) async {
    if (!_isStale(file)) {
      return false;
    }
    final breaker = File('${file.path}.break');
    try {
      await breaker.create(exclusive: true);
    } on FileSystemException {
      // Another waiter breaking it, or a waiter that died doing it.
      if (_isStale(breaker)) {
        try {
          await breaker.delete();
        } catch (_) {}
      }
      return false;
    }
    try {
      if (_isStale(file)) {
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

class _GlobalLockIoHandle implements GlobalLockHandle {
  _GlobalLockIoHandle._(this._file, this._token, Duration interval) {
    _heartbeat = Timer.periodic(interval, (_) {
      try {
        _file.setLastModifiedSync(DateTime.now());
      } catch (_) {}
    });
  }

  /// Writes the owner (pid and a token) in [file], just created, and starts
  /// the heartbeat.
  static Future<_GlobalLockIoHandle> start(File file, Duration interval) async {
    final token = '$pid ${_random.nextInt(1 << 31)}${_random.nextInt(1 << 31)}';
    try {
      await file.writeAsString(token, flush: true);
    } catch (_) {}
    return _GlobalLockIoHandle._(file, token, interval);
  }

  final File _file;
  final String _token;
  Timer? _heartbeat;

  @override
  Future<void> release() async {
    final heartbeat = _heartbeat;
    if (heartbeat == null) {
      return;
    }
    heartbeat.cancel();
    _heartbeat = null;
    try {
      // Taken over (frozen past the stale timeout): the file of another.
      if (await _file.readAsString() == _token) {
        await _file.delete();
      }
    } catch (_) {}
  }
}
