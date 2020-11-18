import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future<void> main() async {
  var shell = Shell();

  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  var dartExtraOptions = '';
  var dartRunExtraOptions = '';
  var dart = Platform.executable;

  if (nnbdEnabled) {
    // Needed for run and test
    dartRunExtraOptions = '$dartExtraOptions --no-sound-null-safety';

    for (var dir in ['synchronized']) {
      shell = shell.pushd(dir);
      stdout.writeln('package: $dir');
      await shell.run('''

$dart $dartExtraOptions pub get
$dart $dartRunExtraOptions run tool/travis.dart

    ''');
      shell = shell.popd();
    }
  } else {
    stderr.writeln('NNBD skipped on dart $dartVersion');
  }
}
