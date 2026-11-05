import 'dart:math';

/// Unique to this run: other test runs may use the machine at the same time.
final _runId = Random().nextInt(1000000);
var _nameCount = 0;

/// A new lock name for this run.
String newGlobalLockName() => 'synchronized_test_${_runId}_${++_nameCount}';
