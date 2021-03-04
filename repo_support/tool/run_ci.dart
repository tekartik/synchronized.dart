import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:dev_test/package.dart';
import 'package:path/path.dart';

Future<void> main() async {
  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    for (var dir in ['synchronized']) {
      await packageRunCi(join('..', dir));
    }
  } else {
    stderr.writeln('NNBD skipped on dart $dartVersion');
  }
}
