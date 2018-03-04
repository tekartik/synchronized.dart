// Copyright (c) 2016, Alexandre Roux Tekartik. All rights reserved. Use of this source code

// is governed by a BSD-style license that can be found in the LICENSE file.

import 'lock_test.dart';
import 'package:dev_test/test.dart';
import 'test_common.dart';

main() {
  group('SynchronizedLock', () {
    lockMain(new SynchronizedLockFactory());
  });
}
