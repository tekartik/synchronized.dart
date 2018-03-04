import 'dart:async';
export 'dart:async';

// await sleep(500)
Future sleep(int ms) => new Future.delayed(new Duration(milliseconds: ms));

@deprecated
void devPrint(Object object) {
  print(object);
}
