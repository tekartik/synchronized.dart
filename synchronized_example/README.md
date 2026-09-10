# synchronized_example

Example consumer of `package:synchronized`.

It shows how the agent skill shipped in `synchronized/skills/` reaches a
consumer project through the [pub package skills](https://dart.dev/tools/pub/package-skills)
mechanism.

## Install the skills

```bash
dart run tool/get_skills.dart
```

This runs `dart run skills@ get` for the `claude`, `codex` and `copilot`
agents, which installs `synchronized-lock` in:

| Agent            | Directory                 |
|------------------|---------------------------|
| claude           | `.claude/skills/`         |
| codex (generic)  | `.agents/skills/`         |
| copilot (github) | `.github/skills/`         |
| gemini           | `.gemini/skills/` (copied from `.agents/skills/`) |

The `skills` tool has no Gemini adapter, so the script copies the generic
`.agents/skills/` install into `.gemini/skills/`.

The installed directories are git-ignored; `test/skills_test.dart` regenerates
them and checks that each one contains the skill as published by the package.
