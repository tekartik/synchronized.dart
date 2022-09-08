import 'dart:async';

export 'dart:async';

/// Helper for a simple pause à la C.
Future<void> sleep(int ms) => Future.delayed(Duration(milliseconds: ms));

/// Used during development for printing out messages.
///
/// Deprecated on purpose to avoid leaving it in the code.
@Deprecated('Dev only')
void devPrint(Object object) {
  print(object);
}

/// Used to debug lock acqusitions and releases
void debug(String? debugLabel, String message) {
  if (debugLabel != null) {
    print('[LOCK - $debugLabel]: $message');
  }
}
