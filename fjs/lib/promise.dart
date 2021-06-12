import 'dart:async';

import 'lifetime.dart';
import 'vm.dart';
import 'types.dart';

/**
 * QuickJSDeferredPromise wraps a QuickJS promise and allows
 * [[resolve]]ing or [[reject]]ing that promise. Use it to bridge asynchronous
 * code on the host to APIs inside a QuickJSVm.
 *
 * Managing the lifetime of promises is tricky. There are three
 * [[QuickJSHandle]]s inside of each deferred promise object: (1) the promise
 * itself, (2) the `resolve` callback, and (3) the `reject` callback.
 *
 * - If the promise will be fufilled before the end of it's [[owner]]'s lifetime,
 *   the only cleanup necessary is `deferred.handle.dispose()`, because
 *   calling [[resolve]] or [[reject]] will dispose of both callbacks automatically.
 *
 * - As the return value of a [[VmFunctionImplementation]], return [[handle]],
 *   and ensure that either [[resolve]] or [[reject]] will be called. No other
 *   clean-up is necessary.
 *
 * - In other cases, call [[dispose]], which will dispose [[handle]] as well as the
 *   QuickJS handles that back [[resolve]] and [[reject]]. For this object,
 *   [[dispose]] is idempotent.
 */
class JSDeferredPromise implements Disposable {
  final Vm owner;
  final Lifetime<JSValuePointer> _promise;
  final Lifetime<JSValuePointer> _resolve;
  final Lifetime<JSValuePointer> _reject;

  /**
   * A native promise that will resolve once this deferred is settled.
   */
  late Future<void> settled;
  late void Function() onSettled;

  Lifetime<JSValuePointer> get promise => _promise;

  JSDeferredPromise(
      this.owner, this._promise, this._resolve, this._reject, [Future? future]) {
    if(future != null) {
      this.settled = future;
      this.onSettled = () {};
    } else {
      Completer completer = Completer();
      this.settled = completer.future;
      this.onSettled = () => completer.complete();
    }
  }

  /**
   * Resolve [[resolve]] with the given value, if any.
   * Calling this method after calling [[dispose]] is a no-op.
   *
   * Note that after resolving a promise, you may need to call
   * [[executePendingJobs]] to propagate the result to the promise's
   * callbacks.
   */
  void resolve(JSValuePointer? value) {
    if (!_resolve.alive) {
      return;
    }
    owner.callVoidFunction(
        this._resolve.value, owner.nullThis, [value ?? owner.$undefined]);
    this._disposeResolvers();
    this.onSettled();
  }

  /**
   * Reject [[reject]] with the given value, if any.
   * Calling this method after calling [[dispose]] is a no-op.
   *
   * Note that after rejecting a promise, you may need to call
   * [[executePendingJobs]] to propagate the result to the promise's
   * callbacks.
   */
  reject(JSValuePointer? value) {
    if (!_reject.alive) {
      return;
    }
    owner.callVoidFunction(
        this._reject.value, owner.nullThis, [value ?? owner.$undefined]);
    this._disposeResolvers();
    this.onSettled();
  }

  get alive {
    return _promise.alive || _resolve.alive || _reject.alive;
  }

  dispose() {
    if (_promise.alive) {
      _promise.dispose();
    }
    this._disposeResolvers();
  }

  _disposeResolvers() {
    if (_resolve.alive) {
      _resolve.dispose();
    }
    if (_reject.alive) {
      _reject.dispose();
    }
  }
}