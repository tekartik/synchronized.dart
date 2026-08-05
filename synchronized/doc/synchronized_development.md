# Development

## Guidelines

* run tests
* no warning
* `strict-casts` and `strict-inference` are enabled (see `analysis_options.yaml`)

````
# quick run before committing

dart format .
dart analyze
dart test
````

The full gate that CI runs (analyze + format + test, for every package in the
repo) is:

````
cd repo_support
dart run tool/run_ci.dart
````

## Browser and node test

````
dart test -p chrome

# full test in one
dart test -p chrome -p node -p vm
# Using build_runner
dart run build_runner test -- -p chrome -p vm
````
    
## Use the git version

```
dependency_overrides:
  synchronized:
    git: https://github.com/tekartik/synchronized.dart
```

## Run perf test

`perf_test_runner.dart` does not end in `_test.dart`, so the default glob
skips it. Run it explicitly:

    dart test -j 1 test/perf_test_runner.dart

Historical numbers, kept for reference only — they are not a regression gate:

```
2019-02-21
2.1.0
00:00 +0: BasicLock 500000 operations                                                                                                                                                                                                                                                                                                                        
 none 0:00:00.002481
await 0:00:02.301012
syncd 0:00:06.282630
00:09 +1: ReentrantLock 500000 operations                                                                                                                                                                                                                                                                                                                    
 none 0:00:00.001706
await 0:00:02.245424
syncd 0:00:13.592300
```

### Publishing

     dart pub publish


Post publish

    git tag vX.Y.Z
    git push origin --tags

