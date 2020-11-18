//@dart=2.9
import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future<void> main() async {
  var shell = Shell();

  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  var dartRunExtraOptions = '';
  var dart = Platform.executable;

  if (nnbdEnabled) {
    // Needed for run and test
    dartRunExtraOptions = '--no-sound-null-safety';

    await shell.run('''

$dart analyze --fatal-warnings --fatal-infos .
$dart format -o none --set-exit-if-changed .

$dart $dartRunExtraOptions run  test -p vm,chrome,firefox -j 1
$dart $dartRunExtraOptions run build_runner test -- -p vm,chrome -j 1
  ''');
  }
}
