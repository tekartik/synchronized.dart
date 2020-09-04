import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future<void> main() async {
  var shell = Shell();

  var enableNnbd = dartVersion > Version(2, 10, 0, pre: '92');
  var dartExtraOptions = '';
  var dartRunExtraOptions = '';
  if (enableNnbd) {
    // Temp dart extra option. To remove once nnbd supported on stable without flags
    dartExtraOptions = '--enable-experiment=non-nullable';
    // Needed for run and test
    dartRunExtraOptions =
        '--enable-experiment=non-nullable --no-sound-null-safety';

    for (var dir in ['synchronized']) {
      shell = shell.pushd(dir);
      stdout.writeln('package: $dir');
      await shell.run('''

dart $dartExtraOptions pub get
dart $dartRunExtraOptions run tool/travis.dart

    ''');
      shell = shell.popd();
    }
  } else {
    stderr.writeln('NNBD skipped on dart $dartVersion');
  }
}
