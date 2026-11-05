/// A lock shared beyond the current isolate, identified by a name: across the
/// isolates and processes of the machine (io) or the tabs and workers of the
/// origin (web).
///
/// ```dart
/// import 'package:synchronized/global_lock.dart';
///
/// final lock = GlobalLock('my_app_firebase_emulator');
///
/// Future<void> useTheEmulator() async {
///   await lock.synchronized(() async {
///     // Only one isolate or process of the machine runs this at a time.
///   }, timeout: const Duration(minutes: 10));
/// }
/// ```
library;

export 'src/global_lock.dart' show GlobalLock, GlobalLockHandle;
