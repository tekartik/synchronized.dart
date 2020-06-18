import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Version parsePlatformVersion(String text) {
  return Version.parse(text.split(' ').first);
}

Future main() async {
  var shell = Shell();

  await shell.run('''

dartanalyzer --fatal-warnings --fatal-infos .
dartfmt -n --set-exit-if-changed .

pub run test -p vm -j 1
pub run build_runner test -- -p vm -j 1
pub run test -p chrome,firefox -j 1
''');

  // Fails on Dart 2.5.0
  var dartVersion = parsePlatformVersion(Platform.version);
  if (dartVersion > Version(2, 5, 0)) {
    await shell.run('''
    pub run build_runner test -- -p chrome -j 1
  ''');
  }
}
