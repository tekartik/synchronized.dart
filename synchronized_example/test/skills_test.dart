@TestOn('vm')
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:synchronized_example/synchronized_example.dart';
import 'package:test/test.dart';

void main() {
  var projectPath = p.normalize(p.absolute('.'));
  var packageSkillPath = p.join(
    projectPath,
    '..',
    'synchronized',
    'skills',
    synchronizedSkillName,
    'SKILL.md',
  );

  group('skills', () {
    setUpAll(() async {
      // Start from a clean state so the test proves the install, not a
      // leftover from a previous run.
      for (var dir in allAgentSkillsDirs.values) {
        var directory = Directory(p.join(projectPath, dir));
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      }
      await getSkills(projectPath: projectPath);
    });

    test('package ships the skill', () {
      expect(File(packageSkillPath).existsSync(), isTrue);
    });

    test('splitSkillMarkdown', () {
      expect(splitSkillMarkdown('---\nname: a\n---\nbody\n'), (
        frontmatter: 'name: a',
        body: 'body\n',
      ));
      expect(splitSkillMarkdown('body'), (frontmatter: '', body: 'body'));
    });

    for (var agent in allAgentSkillsDirs.keys) {
      test('installed for $agent', () {
        var installedPath = installedSkillPath(projectPath, agent);
        expect(
          File(installedPath).existsSync(),
          isTrue,
          reason: '$installedPath not found',
        );
        var installed = splitSkillMarkdown(
          File(installedPath).readAsStringSync(),
        );
        var source = splitSkillMarkdown(
          File(packageSkillPath).readAsStringSync(),
        );
        // Adapters may add frontmatter fields, never change the body.
        expect(installed.frontmatter, contains('name: $synchronizedSkillName'));
        expect(installed.body, source.body);
      });
    }
  });
}
