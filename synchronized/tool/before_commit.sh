#!/usr/bin/env bash


# Fast fail the script on failures.
set -e

# quick run before checking
dartfmt -w .
dartanalyzer .
pub run test -j 1