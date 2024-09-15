// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'common_lock_test_.dart' as lock_test;
import 'lock_factory.dart';

void main() {
  final lockFactory = CombinedLockFactory();
  group('BasicLock', () {
    // Common tests
    lock_test.lockMain(lockFactory);
  });
}
