import 'dart:async';
import 'dart:html';
import 'package:synchronized/synchronized.dart';

PreElement outElement;

print(msg) {
  if (outElement == null) {
    outElement = querySelector("#output") as PreElement;
  }
  outElement.text += "${msg}\n";
}

Future writeSlow(int value) async {
  new Future.delayed(new Duration(milliseconds: 1));
  print(value);
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
    print("not synchronized");
    //await Future.wait([write1234(), write1234()]);
    write1234();
    write1234();

    await new Future.delayed(new Duration(milliseconds: 50));
  }

  Future test2() async {
    print("synchronized");
    var lock = new Lock();

    lock.synchronized(write1234);
    lock.synchronized(write1234);

    await new Future.delayed(new Duration(milliseconds: 50));
  }

  Future test3() async {
    print("lock.synchronized");

    var lock = new Lock();
    lock.synchronized(write1234);
    lock.synchronized(write1234);

    await new Future.delayed(new Duration(milliseconds: 50));
  }

  Future test4() async {
    print("basic");
    var lock = new Lock();
    await lock.synchronized(() async {
      // do you stuff
      // await ...
    });
  }

  Future readme1() async {
    var lock = new Lock();

    // ...
    await lock.synchronized(() async {
      // do some stuff
    });
  }

  Future readme2() async {
    var lock = new Lock();
    if (!lock.locked) {
      lock.synchronized(() async {
        // do some stuff
      });
    }
  }

  Future readme3() async {
    var lock = new Lock();

    int value = await lock.synchronized(() {
      return 1;
    });
    print("got value: ${value}");
  }
}

main() async {
  Demo demo = new Demo();

  await demo.test1();
  await demo.test2();
  await demo.test3();
  await demo.test4();
  await demo.readme1();
  await demo.readme1();
  await demo.readme3();
}
