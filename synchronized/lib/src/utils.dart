import 'dart:async';

export 'dart:async';

/// Helper for a simple pause à la C.
Future<void> sleep(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

/// Used during development for printing out messages.
///
/// Deprecated on purpose to avoid leaving it in the code.
@Deprecated('Dev only')
void devPrint(Object object) {
  // ignore: avoid_print
  print(object);
}
