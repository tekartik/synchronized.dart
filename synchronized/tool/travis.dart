import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future<void> main() async {
  // Uncomment to use a different dart installation
  // var env = ShellEnvironment()..aliases.addAll({'dart': '/my/other/dart'});
  // var shell = Shell(environment: env);
  // await shell.run('dart --version');

  var shell = Shell();

  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    await shell.run('''

dart analyze --fatal-warnings --fatal-infos .
dart format -o none --set-exit-if-changed .

dart test -p vm,chrome,firefox -j 1
dart run build_runner test -- -p vm,chrome -j 1
  ''');
  }
}
