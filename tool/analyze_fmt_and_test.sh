#!/bin/bash

# Fast fail the script on failures.
set -xe

dartfmt -w .
dartanalyzer --fatal-warnings example lib test

pub run test -p vm
pub run build_runner test