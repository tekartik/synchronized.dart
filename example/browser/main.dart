import 'dart:async';
import 'dart:html';
import 'package:synchronized/synchronized.dart';

PreElement outElement;

print(msg) {
  if (outElement == null) {
    outElement = querySelector("#output");
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

    synchronized(this, write1234);
    synchronized(this, write1234);

    await new Future.delayed(new Duration(milliseconds: 50));
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
    print("got value: ${value}");
  }
}

main() async {
  Demo demo = new Demo();

  await demo.test1();
  await demo.test2();
  await demo.readme1();
  await demo.readme1();
  await demo.readme3();
}
