# Development

## Guidelines

* run tests
* no warning
* string mode / implicit-casts: false

````
# quick run before commiting

dartfmt -w .
dartanalyzer .
pub run test
````
    
## Use the git version

```
dependency_overrides:
  synchronized:
    git: git://github.com/tekartik/synchronized.dart
```
## Run perf test

    pub run test -n "10000 operations" -j 1

```
00:00 +0: test/lock_test.dart: Lock synchronized perf 10000 operations                                                                                                                                                                                                                                             
none 0:00:00.000561
await 0:00:00.173930
syncd 0:00:00.382899
00:00 +1: test/synchronized_lock_test.dart: SynchronizedLock synchronized perf 10000 operations                                                                                                                                                                                                                    
none 0:00:00.000453
await 0:00:00.132460
syncd 0:00:00.459393
```

### Publishing

     pub publish

