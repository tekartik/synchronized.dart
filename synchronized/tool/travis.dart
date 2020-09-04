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

    await shell.run('''

dartanalyzer $dartExtraOptions --fatal-warnings --fatal-infos .
dartfmt -n --set-exit-if-changed .

pub run $dartRunExtraOptions test -p vm -j 1
# NNBD failing - dart $dartRunExtraOptions pub run build_runner test -- -p vm -j 1
# NNBD failing - pub run $dartRunExtraOptions test -p chrome,firefox -j 1
# NNBD failing - pub run $dartRunExtraOptions build_runner test -- -p chrome -j 1
  ''');
  }
}
