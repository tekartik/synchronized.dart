#!/bin/bash

# Fast fail the script on failures.
set -xe

dartfmt --fix -w . example lib test
dartanalyzer --fatal-warnings --fatal-infos example lib test

pub run test -p vm
pub run build_runner test