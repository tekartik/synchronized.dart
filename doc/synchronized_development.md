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

## Browser and node test

````
pub run test -p chrome

# full test in one
pub run test -p chrome -p firefox -p vm
# Using build_runner
pub run build_runner test -- -p chrome -p firefox -p vm
````
    
## Use the git version

```
dependency_overrides:
  synchronized:
    git: git://github.com/tekartik/synchronized.dart
```

## Run perf test

    pub run test -j 1 test/perf_test_.dart 

```
00:00 +0: BasicLock 500000 operations                                                                                                                                                                                                                                                                                                                        
 none 0:00:00.002528
await 0:00:02.133616
syncd 0:00:05.874782
00:08 +1: ReentrantLock 500000 operations                                                                                                                                                                                                                                                                                                                    
 none 0:00:00.001413
await 0:00:02.062770
syncd 0:00:06.111465
```

### Publishing

     pub publish

