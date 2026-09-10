import 'package:dev_build/package.dart';
import 'package:path/path.dart';

Future<void> main() async {
  for (var dir in ['synchronized', 'synchronized_example', 'repo_support']) {
    await packageRunCi(join('..', dir));
  }
}
