import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future<void> main() async {
  var shell = Shell();

  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    for (var dir in ['synchronized']) {
      shell = shell.pushd(dir);
      stdout.writeln('package: $dir');
      await shell.run('''

dart pub get
dart tool/travis.dart

    ''');
      shell = shell.popd();
    }
  } else {
    stderr.writeln('NNBD skipped on dart $dartVersion');
  }
}
