# synchronized

[![Build Status](https://travis-ci.org/tekartik/synchronized.dart.svg?branch=master)](https://travis-ci.org/tekartik/synchronized.dart)

Basic lock mechanism for prevent concurrent access to resources

## Goal

You were missing hard to debug deadlocks, here it is! 

The goal is to propose a solution similar to
 * Critical Section
 * Synchronized à la Java style
 * Transaction
 * Lock/Mutex mechanism

The goal is to ensure for a single process (single isolate) that some asynchronous operation can be run
without conflict. It won't solve cross-process synchronization.

For single process (single isolate) accessing some resources (database..), it can help to
 * Provide transaction on database system that don't have transaction mechanism (mongodbn, ...)
 * In html application make sure some asynchrous UI operation are not conflicting (login)

## Feature

 * Synchronized block are reintrant
 * Timeout support
 * Consistent behavior
 * Work on Browser and DartVM

## Usage

A simple usage example:

    import 'package:synchronized/synchronized.dart';

    main() {
      var lock = new Object();
      synchronized(lock, () async {
        // Only this block can run (once) until done 
        ...
      });
    }
    
Any object can become a locker, so in a class method you can use

    synchronized(this, () async {
      // do some stuff
    });

A SynchronizedLock object has a locked helper method

    var lock = new SynchronizedLock();
    if (!lock.locked) {
      lock.synchronized(() async {
        // do some stuff
      });
    }
    
The return value is preserved

    int value = await synchronized(this, () {
      return 1;
    });
    

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/tekartik/synchronized.dart/issues
