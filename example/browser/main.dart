import 'dart:async';
import 'dart:html';
import 'package:synchronized/synchronized.dart';

PreElement outElement;

void print(dynamic msg) {
  if (outElement == null) {
    outElement = querySelector("#output") as PreElement;
  }
  outElement.text += "$msg\n";
}

Future writeSlow(int value) async {
  await Future.delayed(Duration(milliseconds: 1));
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
    // ignore: unawaited_futures
    write1234();
    // ignore: unawaited_futures
    write1234();

    await Future.delayed(Duration(milliseconds: 50));
  }

  Future test2() async {
    print("synchronized");
    var lock = Lock();

    // ignore: unawaited_futures
    lock.synchronized(write1234);
    // ignore: unawaited_futures
    lock.synchronized(write1234);

    await Future.delayed(Duration(milliseconds: 50));
  }

  Future test3() async {
    print("lock.synchronized");

    var lock = Lock();
    // ignore: unawaited_futures
    lock.synchronized(write1234);
    // ignore: unawaited_futures
    lock.synchronized(write1234);

    await Future.delayed(Duration(milliseconds: 50));
  }

  Future test4() async {
    print("basic");
    var lock = Lock();
    await lock.synchronized(() async {
      // do you stuff
      // await ...
    });
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
    print("got value: $value");
  }
}

Future main() async {
  Demo demo = Demo();

  await demo.test1();
  await demo.test2();
  await demo.test3();
  await demo.test4();
  await demo.readme1();
  await demo.readme1();
  await demo.readme3();
}
