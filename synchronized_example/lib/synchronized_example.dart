/// Helpers to install and locate the `synchronized` agent skills in a
/// consumer project.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:process_run/shell.dart';

/// Name of the skill shipped by `package:synchronized`.
const synchronizedSkillName = 'synchronized-lock';

/// Agents that the `skills` tool installs for, mapped to their install
/// directory relative to the project root.
const skillsToolAgentDirs = <String, String>{
  'claude': '.claude/skills',
  'codex': '.agents/skills',
  'copilot': '.github/skills',
};

/// Gemini is not known by the `skills` tool: its directory is populated by
/// copying the generic `.agents/skills` install.
const geminiSkillsDir = '.gemini/skills';

/// All agent skills directories expected after [getSkills], relative to the
/// project root.
const allAgentSkillsDirs = <String, String>{
  ...skillsToolAgentDirs,
  'gemini': geminiSkillsDir,
};

/// Splits a `SKILL.md` content into its YAML frontmatter and markdown body.
///
/// Agent adapters may add fields to the frontmatter (Claude adds
/// `user-invocable: false`), so consumers comparing an installed skill with
/// its source should compare bodies.
({String frontmatter, String body}) splitSkillMarkdown(String content) {
  var lines = content.split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') {
    return (frontmatter: '', body: content);
  }
  var end = lines.indexWhere((line) => line.trim() == '---', 1);
  if (end < 0) {
    return (frontmatter: '', body: content);
  }
  return (
    frontmatter: lines.sublist(1, end).join('\n'),
    body: lines.sublist(end + 1).join('\n'),
  );
}

/// Path of the installed `SKILL.md` for [agent] in [projectPath].
String installedSkillPath(String projectPath, String agent) => p.join(
  projectPath,
  allAgentSkillsDirs[agent]!,
  synchronizedSkillName,
  'SKILL.md',
);

/// Runs `dart run skills@ get` in [projectPath] for every agent in
/// [skillsToolAgentDirs], then mirrors the generic install into
/// [geminiSkillsDir].
Future<void> getSkills({
  required String projectPath,
  bool verbose = false,
}) async {
  var shell = Shell(workingDirectory: projectPath, verbose: verbose);
  await shell.run('dart pub get');
  for (var agent in skillsToolAgentDirs.keys) {
    await shell.run(
      'dart run skills@ get --agent $agent --skill $synchronizedSkillName',
    );
  }
  await _copyDirectory(
    Directory(p.join(projectPath, skillsToolAgentDirs['codex']!)),
    Directory(p.join(projectPath, geminiSkillsDir)),
  );
}

Future<void> _copyDirectory(Directory src, Directory dst) async {
  if (dst.existsSync()) {
    await dst.delete(recursive: true);
  }
  await dst.create(recursive: true);
  await for (var entity in src.list(recursive: true)) {
    var target = p.join(dst.path, p.relative(entity.path, from: src.path));
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
    } else if (entity is File) {
      await File(target).parent.create(recursive: true);
      await entity.copy(target);
    }
  }
}
