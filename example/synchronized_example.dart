import 'dart:async';
import 'dart:io';
import 'package:synchronized/synchronized.dart';

Future writeSlow(int value) async {
  await Future.delayed(Duration(milliseconds: 1));
  stdout.write(value);
}

Future write(List<int> values) async {
  for (int value in values) {
    await writeSlow(value);
  }
}

Future write1234() async {
  await write([1, 2, 3, 4]);
}

class Demo {
  Future test1() async {
    stdout.writeln("not synchronized");
    //await Future.wait([write1234(), write1234()]);
    // ignore: unawaited_futures
    write1234();
    // ignore: unawaited_futures
    write1234();

    await Future.delayed(Duration(milliseconds: 50));
    stdout.writeln();
  }

  Future test2() async {
    stdout.writeln("synchronized");

    var lock = Lock();
    // ignore: unawaited_futures
    lock.synchronized(write1234);
    // ignore: unawaited_futures
    lock.synchronized(write1234);

    await Future.delayed(Duration(milliseconds: 50));

    stdout.writeln();
  }

  Future readme1() async {
    var lock = Lock();

    // ...
    await lock.synchronized(() async {
      // do some stuff
    });
  }

  Future readme2() async {
    var lock = Lock();
    if (!lock.locked) {
      await lock.synchronized(() async {
        // do some stuff
      });
    }
  }

  Future readme3() async {
    var lock = Lock();
    int value = await lock.synchronized(() {
      return 1;
    });
    stdout.writeln("got value: ${value}");
  }
}

Future main() async {
  var demo = Demo();

  await demo.test1();
  await demo.test2();
  await demo.readme1();
  await demo.readme1();
  await demo.readme3();
}
