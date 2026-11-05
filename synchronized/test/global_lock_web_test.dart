@TestOn('browser')
library;

import 'package:synchronized/global_lock.dart';
import 'package:synchronized/src/global_lock_memory.dart';
import 'package:test/test.dart';

void main() {
  test('GlobalLock uses the Web Locks API', () {
    // Not the fallback within the current isolate.
    expect(GlobalLock('test'), isNot(isA<GlobalLockMemory>()));
  });
}
