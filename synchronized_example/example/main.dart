import 'package:synchronized/synchronized.dart';

final _lock = Lock();
var _counter = 0;

Future<int> increment() => _lock.synchronized(() async {
  final current = _counter;
  await Future<void>.delayed(const Duration(milliseconds: 1));
  _counter = current + 1;
  return _counter;
});

Future<void> main() async {
  await Future.wait(List.generate(10, (_) => increment()));
  // Prints 10: the read-modify-write sequences never interleave.
  // ignore: avoid_print
  print(_counter);
}
