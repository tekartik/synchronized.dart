import 'package:dev_test/package.dart';
import 'package:path/path.dart';

Future<void> main() async {
  for (var dir in ['synchronized', 'repo_support']) {
    await packageRunCi(join('..', dir));
  }
}
