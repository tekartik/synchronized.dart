import 'dart:async';
import 'dart:io';
import 'package:synchronized/synchronized.dart';

Future writeSlow(int value) async {
  new Future.delayed(new Duration(milliseconds: 1));
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
    write1234();
    write1234();

    await new Future.delayed(new Duration(milliseconds: 50));
    stdout.writeln();
  }

  Future test2() async {
    stdout.writeln("synchronized");

    synchronized(this, write1234);
    synchronized(this, write1234);

    await new Future.delayed(new Duration(milliseconds: 50));

    stdout.writeln();
  }

  Future readme1() async {
    synchronized(this, () async {
      // do some stuff
    });
  }

  Future readme2() async {
    var lock = new SynchronizedLock();
    if (!lock.locked) {
      lock.synchronized(() async {
        // do some stuff
      });
    }
  }

  Future readme3() async {
    int value = await synchronized(this, () {
      return 1;
    });
    stdout.writeln("got value: ${value}");
  }
}

main() async {
  var demo = new Demo();

  await demo.test1();
  await demo.test2();
  await demo.readme1();
  await demo.readme1();
  await demo.readme3();
}
