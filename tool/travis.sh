#!/bin/bash

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings \
  lib/synchronized.dart \
  test/synchronized_test.dart \

pub run test -p vm,firefox,chrome