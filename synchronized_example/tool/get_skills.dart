import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:synchronized_example/synchronized_example.dart';

/// Installs the `synchronized` skills for every supported agent in this
/// package.
Future<void> main() async {
  var projectPath = p.dirname(p.dirname(p.fromUri(Platform.script)));
  await getSkills(projectPath: projectPath, verbose: true);
}
