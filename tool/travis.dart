import 'package:process_run/shell.dart';

Future<void> main() async {
  var shell = Shell();

  for (var dir in ['synchronized']) {
    shell = shell.pushd(dir);
    await shell.run('''

pub get
dart tool/travis.dart

    ''');
    shell = shell.popd();
  }
}
