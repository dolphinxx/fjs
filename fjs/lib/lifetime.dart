import 'error.dart';

/**
 * An object that can be disposed.
 * [[Lifetime]] is the canonical implementation of Disposable.
 * Use [[Scope]] to manage cleaning up multiple disposables.
 */
abstract class Disposable {
  /**
   * Dispose of the underlying resources used by this object.
   */
  void dispose();

  /**
   * @returns true if the object is alive
   * @returns false after the object has been [[dispose]]d
   */
  bool get alive;
}

typedef Disposer<T> = void Function(T value);

void scopeFinally(Scope scope, [BlockError? blockError]) {
  DisposeError? disposeError;
  try {
    scope.dispose();
  } catch (error, s) {
    disposeError = DisposeError(error.toString(), s);
  }

  if (blockError != null && disposeError != null) {
    blockError.message =
    '${blockError.message}\n Then, failed to dispose scope: ${disposeError.message}';
    blockError.disposeError = disposeError;
    throw blockError;
  }

  if (blockError != null || disposeError != null) {
    throw blockError ?? disposeError!;
  }
}

/**
 * A lifetime prevents access to a value after the lifetime has been
 * [[dispose]]ed.
 *
 * Typically, quickjs-emscripten uses Lifetimes to protect C memory pointers.
 */
class Lifetime<T> implements Disposable {
  bool _alive = true;

  final T _value;
  final Disposer<T>? disposer;
  // final dynamic _owner;
  Scope? _scope;

  /**
   * When the Lifetime is disposed, it will call `disposer(_value)`. Use the
   * disposer function to implement whatever cleanup needs to happen at the end
   * of `value`'s lifetime.
   *
   * `_owner` is not used or controlled by the lifetime. It's just metadata for
   * the creator.
   */
  Lifetime(this._value, [this.disposer, /*this._owner*/this._scope]);

  bool get alive {
    return this._alive;
  }

  /**
   * The value this Lifetime protects. You must never retain the value - it
   * may become invalid, leading to memory errors.
   *
   * @throws If the lifetime has been [[dispose]]d already.
   */
  T get value {
    this._assertAlive();
    return this._value;
  }

  // dynamic get owner {
  //   return this._owner;
  // }

  /**
   * Call `map` with this lifetime, then dispose the lifetime.
   * @return the result of `map(this)`.
   */
// consume<O>(map: (lifetime: this) => O): O
// A specific type definition is needed for our common use-case
// https://github.com/microsoft/TypeScript/issues/30271
// consume<O>(map: (lifetime: QuickJSHandle) => O): O
  O consume<O>(O Function(Lifetime<T> lifetime) map) {
    this._assertAlive();
    try {
      final result = map(this);
      return result;
    } finally {
      this.dispose();
    }
  }

  /**
   * Dispose of [[value]] and perform cleanup.
   */
  void dispose() {
    this._assertAlive();
    if (disposer != null) {
      disposer!(_value);
    }
    _alive = false;
    if(_scope != null) {
      _scope!.remove(this);
    }
  }

  _assertAlive() {
    if (!this.alive) {
      throw DisposeError('Lifetime not alive');
    }
  }
}

/**
 * A Lifetime that lives forever. Used for constants.
 */
class StaticLifetime<T> extends Lifetime<T> {
  StaticLifetime(T value) : super(value, null, null);

// Dispose does nothing.
  void dispose() {}
}

/**
 * A Lifetime that does not own its `value`. A WeakLifetime never calls its
 * `disposer` function, but can be `dup`ed to produce regular lifetimes that
 * do.
 *
 * Used for function arguments.
 */
class WeakLifetime<T> extends Lifetime<T> {
  WeakLifetime(
      T value,
      [Disposer<T>? disposer,
      Scope? scope,]
      ) : super(value, disposer, scope); // We don't care if the disposer doesn't support freeing T

  dispose() {
    this._alive = false;
  }
}

/**
 * Scope helps reduce the burden of manually tracking and disposing of
 * Lifetimes. See [[withScope]]. and [[withScopeAsync]].
 */
class Scope implements Disposable {
  bool _alive = true;
  /**
   * Run `block` with a new Scope instance that will be disposed after the block returns.
   * Inside `block`, call `scope.manage` on each lifetime you create to have the lifetime
   * automatically disposed after the block returns.
   *
   * @warning Do not use with async functions. Instead, use [[withScopeAsync]].
   */
  static R withScope<R>(R Function(Scope scope) block) {
    final scope = Scope();
    BlockError? blockError;
    try {
      return block(scope);
    } catch (error, s) {
      blockError = BlockError(error.toString(), s);
      rethrow;
    } finally {
      scopeFinally(scope, blockError);
    }
  }

  /**
   * Run `block` with a new Scope instance that will be disposed after the
   * block's returned promise settles. Inside `block`, call `scope.manage` on each
   * lifetime you create to have the lifetime automatically disposed after the
   * block returns.
   */
  static Future<R> withScopeAsync<R>(
      Future<R> Function(Scope scope) block) async {
    final scope = Scope();
    BlockError? blockError;
    try {
      return await block(scope);
    } catch (error, s) {
      blockError = BlockError(error.toString(), s);
      throw error;
    } finally {
      scopeFinally(scope, blockError);
    }
  }

  Set<Disposable> _disposables = Set();

  /**
   * Track `lifetime` so that it is disposed when this scope is disposed.
   */
  T manage<T extends Disposable>(T lifetime) {
    this._disposables.add(lifetime);
    if(lifetime is Lifetime) {
      lifetime._scope = this;
    }
    return lifetime;
  }

  void remove(Disposable lifetime) {
    this._disposables.remove(lifetime);
  }

  bool get alive => _alive;

  dispose() {
    final lifetimes = this._disposables.toList().reversed;
    for (final lifetime in lifetimes) {
      if (lifetime.alive) {
        lifetime.dispose();
      }
    }
    this._disposables.clear();
    _alive = false;
  }
}