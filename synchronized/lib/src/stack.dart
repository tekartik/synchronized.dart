///
/// Taken from: https://github.com/ammaratef45/dart_stack under the MIT License.

import 'dart:collection';
import 'dart:core' as core;
import 'dart:core';

/// Implements a classic stack.
class Stack<T> extends core.Iterable<T> {
  final _list = ListQueue<T>();

  /// check if the stack is empty.
  @override
  bool get isEmpty => _list.isEmpty;

  /// check if the stack is not empty.
  @override
  bool get isNotEmpty => _list.isNotEmpty;

  /// push element in top of the stack.
  void push(T e) {
    _list.addLast(e);
  }

  /// get the top of the stack and delete it.
  T pop() {
    var res = _list.last;
    _list.removeLast();
    return res;
  }

  /// get the top of the stack without deleting it.
  T top() {
    return _list.last;
  }

  /// get the size of the stack.
  int size() {
    return _list.length;
  }

  /// get the length of the stack.
  @override
  int get length => size();

  /// returns true if element is found in the stack
  @override
  bool contains(covariant T x) {
    for (var item in _list) {
      if (x == item) {
        return true;
      }
    }
    return false;
  }

  /// Returns an iterator for the list of items
  /// on the stack.
  /// The head of the stack is returned first.
  @override
  Iterator<T> get iterator => _list.iterator;

  /// print stack
  void print() {
    for (var item in List<T>.from(_list).reversed) {
      core.print(item);
    }
  }
}
