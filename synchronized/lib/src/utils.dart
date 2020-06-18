import 'dart:async';
export 'dart:async';

/// Helper for a simple pause à la C.
Future sleep(int ms) => Future.delayed(Duration(milliseconds: ms));

@deprecated

/// Used during development for printing out messages.
///
/// Deprecated on purpose to avoid leaving it in the code.
void devPrint(Object object) {
  print(object);
}
