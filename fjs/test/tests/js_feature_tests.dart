import 'package:fjs/vm.dart';
import 'package:test/test.dart';

void testRegexCapturingGroup(Vm vm) {
  final actual = vm.jsToDart(vm.evalCode(
      r'/(?<greeting>hello)/ig.exec("Hello World!").groups.greeting'));
  expect(actual, 'Hello');
}

/// ```javascript
/// JSON.stringify(undefined)// undefined
/// JSON.stringify(null)// null
/// JSON.stringify(1)// 1
/// JSON.stringify(1.1)// 1.1
/// JSON.stringify(Number(1.1))// 1.1
/// JSON.stringify(new Number(1.1))// 1.1
/// JSON.stringify(NaN)// null
/// JSON.stringify(Infinity)// null
/// JSON.stringify(1/0)// null
/// JSON.stringify(true)// true
/// JSON.stringify(false)// false
/// JSON.stringify(Boolean(true))// true
/// JSON.stringify(Boolean(false))// false
/// JSON.stringify(new Boolean(true))// true
/// JSON.stringify(new Boolean(false))// false
/// JSON.stringify('Hello')// "Hello"
/// JSON.stringify(String('Hello'))// "Hello"
/// JSON.stringify(new String('Hello'))// "Hello"
/// JSON.stringify(`Hello ${'World'}`)// "Hello World"
/// JSON.stringify({a:1,b:true,c:'Hello'})// {"a":1,"b":true,"c":"Hello"}
/// JSON.stringify([1, 'Hello', true])// [1,"Hello",true]
/// JSON.stringify(Symbol('Hello'))// undefined
/// JSON.stringify(/Hello/)// {}
/// JSON.stringify(() => Hello)// undefined
/// ```
void testJSONStringify(Vm vm) {
  List<List<dynamic>> tests = [
    ['undefined', 'undefined'],
    ['null', 'null'],
    ['1', '1'],
    ['1.1', '1.1'],
    ['Number(1.1)', '1.1'],
    ['new Number(1.1)', '1.1'],
    ['NaN', 'null'],
    ['Infinity', 'null'],
    ['1/0', 'null'],
    ['true', 'true'],
    ['false', 'false'],
    ['Boolean(true)', 'true'],
    ['Boolean(false)', 'false'],
    ['new Boolean(true)', 'true'],
    ['new Boolean(false)', 'false'],
    ['"Hello"', '"Hello"'],
    ['String("Hello")', '"Hello"'],
    ['new String("Hello")', '"Hello"'],
    ['`Hello ${"World"}`', '"Hello World"'],
    ['({a:1,b:true,c:"Hello"})', '{"a":1,"b":true,"c":"Hello"}'],
    ['[1, "Hello", true]', '[1,"Hello",true]'],
    ['Symbol("Hello")', 'undefined'],
    ['/Hello/', '{}'],
    ['(() => Hello)', 'undefined'],
  ];
  for(var t in tests) {
    String? actual = vm.JSONStringify(vm.evalCode(t[0]));
    expect(actual, t[1], reason: 'JSON.stringify(${t[0]}) == ${t[1]}');
  }
}

const String JS_EXPECT = r'''
function _compare(a, b, msg) {
  if(Object.is(a, b)) {
    return;
  }
  msg = msg||'';
  var aType = typeof a;
  var bType = typeof b;
  if(aType !== bType) {
    throw `${msg}expected: ${bType}, actual: ${aType}`;
  }
  if(aType === 'object') {
    if(b instanceof Array) {
      if(!(a instanceof Array)) {
        throw `${msg}expected: instanceof Array`;
      }
      if(a.length !== b.length) {
        throw `${msg}arrays have different lengths, expected: ${b.length}, actual: ${a.length}`;
      }
      for(var i = 0;i < a.length;i++) {
        _compare(a[i], b[i], `${msg}array[${i}] `);
      }
    }
    for(var o in b) {
      if(b.hasOwnProperty(o)) {
        if(!a.hasOwnProperty(o)) {
          throw `${msg}expected: object has property ${o}`;
        }
        _compare(a[o], b[o], `${msg}Object property ${o} `);
      }
    }
    return;
  }
  throw `${msg}expected: ${b.toString()}, actual: ${a.toString()}`;
}
function expect(actual, expected, msg) {
  _compare(actual, expected, msg);
}
      ''';

/// from [http://es6-features.org/](http://es6-features.org/)
abstract class ES6Features {
  static const Constants = r'''
const PI = 3.141593
expect(PI > 3.0, true)
''';

  static const BlockScopedVariables = r'''
var a = [1, 2, 3, 4, 5];
for (let i = 0; i < a.length; i++) {
    let x = a[i]
}
var b = [6, 7, 8, 9, 10]
for (let i = 0; i < b.length; i++) {
    let y = b[i]
}

let callbacks = []
for (let i = 0; i <= 2; i++) {
    callbacks[i] = function () { return i * 2 }
}
expect(callbacks[0](), 0)
expect(callbacks[1](), 2)
expect(callbacks[2](), 4)
''';

  static const BlockScopedFunctions = r'''
{
    function foo () { return 1 }
    expect(foo(), 1, 'first call ')
    {
        function foo () { return 2 }
        expect(foo(), 2, 'second call ')
    }
    expect(foo(), 1, 'third call ')
}
''';

  static const ArrowExpressBodies = r'''
var evens = [0, 2, 4, 6, 8, 10];
var odds  = evens.map(v => v + 1)
expect(odds, [1, 3, 5, 7, 9, 11]);
var pairs = evens.map(v => ({ even: v, odd: v + 1 }))
expect(pairs, [{even: 0, odd: 1}, {even: 2, odd: 3}, {even: 4, odd: 5}, {even: 6, odd: 7}, {even: 8, odd: 9}, {even: 10, odd: 11}, ])
var nums  = evens.map((v, i) => v + i)
expect(nums, [0, 3, 6, 9, 12, 15])
''';

  static const ArrowStatementBodies = r'''
const nums = [1,2,3,4,5,6,7,8,9,10];
const fives = [];
nums.forEach(v => {
   if (v % 5 === 0)
       fives.push(v)
})
expect(fives, [5, 10]);
''';

  static const ArrowLexicalThis = r'''
this.nums = [1,2,3,4,5,6,7,8,9,10];
this.fives = [];
this.nums.forEach((v) => {
    if (v % 5 === 0)
        this.fives.push(v)
});
expect(fives, [5, 10]);
''';

  static const DefaultParameterValues = r'''
function f (x, y = 7, z = 42) {
    return x + y + z
}
expect(f(1), 50)
''';

  static const RestParameter = r'''
function f (x, y, ...a) {
    return (x + y) * a.length
}
expect(f(1, 2, "hello", true, 7), 9)
''';

  static const SpreadOperator = r'''
var params = [ "hello", true, 7 ]
var other = [ 1, 2, ...params ] // [ 1, 2, "hello", true, 7 ]

function f (x, y, ...a) {
    return (x + y) * a.length
}
expect(f(1, 2, ...params), 9)

var str = "foo"
var chars = [ ...str ]
expect(chars, [ "f", "o", "o" ]);
''';

  static const StringInterpolation = r'''
var customer = { name: "Foo" }
var card = { amount: 7, product: "Bar", unitprice: 42 }
var message = `Hello ${customer.name},
want to buy ${card.amount} ${card.product} for
a total of ${card.amount * card.unitprice} bucks?`
expect(message, 'Hello Foo,\nwant to buy 7 Bar for\na total of 294 bucks?')
''';

  static const CustomInterpolation = r'''
function get(strings, ...values) {
  return `${strings[0]}${values[0]}${strings[1]}${values[1]}`;
}
var bar = 'BAR';
var baz = 'BAZ';
var quux = 'QUUX';
expect(get`https://example.com/foo?bar=${bar + baz}&quux=${quux}`, 'https://example.com/foo?bar=BARBAZ&quux=QUUX')
''';

  static const RawStringAccess = r'''
function quux (strings, ...values) {
    expect(strings[0], "foo\n")
    expect(strings[1], "bar")
    expect(strings.raw[0], "foo\\n")
    expect(strings.raw[1], "bar")
    expect(values[0], 42)
}
quux`foo\n${ 42 }bar`

expect(String.raw`foo\n${ 42 }bar`, "foo\\n42bar")
''';

  static const BinaryAndOctalLiteral = r'''
expect(0b111110111, 503)
expect(0o767, 503)
''';

  static const UnicodeStringAndRegExpLiteral = r'''
expect("𠮷".length, 2)
expect("𠮷".match(/./u)[0].length, 2)
expect("𠮷", "\uD842\uDFB7")
expect("𠮷", "\u{20BB7}")
expect("𠮷".codePointAt(0), 0x20BB7)
for (let codepoint of "𠮷") console.log(codepoint)
''';

  static const RegularExpressionStickyMatching = r'''
let parser = (input, match) => {
    for (let pos = 0, lastPos = input.length; pos < lastPos; ) {
        for (let i = 0; i < match.length; i++) {
            match[i].pattern.lastIndex = pos
            let found
            if ((found = match[i].pattern.exec(input)) !== null) {
                match[i].action(found)
                pos = match[i].pattern.lastIndex
                break
            }
        }
    }
}

let report = (match) => {
    console.log(JSON.stringify(match))
}
parser("Foo 1 Bar 7 Baz 42", [
    { pattern: /Foo\s+(\d+)/y, action: (match) => report(match) },
    { pattern: /Bar\s+(\d+)/y, action: (match) => report(match) },
    { pattern: /Baz\s+(\d+)/y, action: (match) => report(match) },
    { pattern: /\s*/y,         action: (match) => {}            }
])
''';

  static const PropertyShorthand = r'''
var x = 0, y = 1
var obj = { x, y }
expect(obj, {x: 0, y: 1})
''';

  static const ComputedPropertyNames = r'''
let obj = {
    foo: "bar",
    [ "baz" + "z" ]: 42
}
expect(obj, {foo: 'bar', 'bazz': 42})
''';

  static const MethodProperties = r'''
obj = {
    foo (a, b) {
      return a + b;
    },
    bar (x, y) {
      return x * y;
    },
    *quux (x, y) {
    }
}
expect(obj.foo(1, 2), 3);
''';

  static const ArrayMatching = r'''
var list = [ 1, 2, 3 ]
var [ a, , b ] = list;
expect(a, 1);
expect(b, 3);
[ b, a ] = [ a, b ]
expect(a, 3);
expect(b, 1);
''';

  static const ObjectMatchingShorthandNotation = r'''
function getASTNode() {
  return {
    op: {op: 1},
    lhs: {op:2},
    rhs: {op:3},
    ths: {op:4},
    bhs: {op:5}
  };
}
var { op, lhs, rhs } = getASTNode()
expect(op, {op: 1})
expect(lhs, {op: 2})
expect(rhs, {op: 3})
''';

  static const ObjectDeepMatching = r'''
function getASTNode() {
  return {
    op: {op: 1},
    lhs: {op:2},
    rhs: {op:3},
    ths: {op:4},
    bhs: {op:5}
  };
}
var { op: a, lhs: { op: b }, rhs: c } = getASTNode()
expect(a, {op: 1})
expect(b, 2)
expect(c, {op: 3})
''';

  static const ObjectAndArrayMatchingDefaultValues = r'''
var obj = { a: 1 }
var list = [ 1 ]
var { a, b = 2 } = obj
expect(a, 1);
expect(b, 2);
var [ x, y = 2 ] = list
expect(x, 1)
expect(y, 2)
''';

  static const ParameterContextMatching = r'''
function f ([ name, val ]) {
    console.log(name, val)
}
function g ({ name: n, val: v }) {
    console.log(n, v)
}
function h ({ name, val }) {
    console.log(name, val)
}
f([ "bar", 42 ])
g({ name: "foo", val:  7 })
h({ name: "bar", val: 42 })
''';

  static const FailSoftDestructuringOptionallyWithDefaults = r'''
var list = [ 7, 42 ]
var [ a = 1, b = 2, c = 3, d ] = list
expect(a, 7)
expect(b, 42)
expect(c, 3)
expect(d, undefined)
''';

  static const ValueExport = r'''
//  lib/math.js
export function sum (x, y) { return x + y }
export var pi = 3.141593
  ''';

  static const ValueImport = r'''
import * as math from "lib/math"
expect("2π = " + math.sum(math.pi, math.pi), '2π = 6.283186')
import { sum, pi } from "lib/math"
expect("2π = " + sum(pi, pi), '2π = 6.283186')
  ''';

  static const DefaultAndWildcardExport = r'''
//  lib/mathplusplus.js
export * from "lib/math"
export var e = 2.71828182846
export default (x) => Math.exp(x)
  ''';

  static const DefaultAndWildcardImport = r'''
import exp, { pi, e } from "lib/mathplusplus"
expect("e^{π} = " + exp(pi), 'e^{π} = 23.140700648952773')
  ''';

  static const ClassDefinitionAndInheritance = r'''
class Shape {
    constructor (id, x, y) {
        this.id = id
        this.move(x, y)
    }
    move (x, y) {
        this.x = x
        this.y = y
    }
}

class Rectangle extends Shape {
    constructor (id, x, y, width, height) {
        super(id, x, y)
        this.width  = width
        this.height = height
    }
}
class Circle extends Shape {
    constructor (id, x, y, radius) {
        super(id, x, y)
        this.radius = radius
    }
}
var rectangle = new Rectangle(1, 50, 50, 100, 200);
rectangle.move(100, 100);
expect(rectangle.x, 100);
var circle = new Circle(2, 50, 50, 100);
circle.move(200, 200);
expect(circle.x, 200);
''';

  static const ClassInheritanceFromExpressions = r'''
var aggregation = (baseClass, ...mixins) => {
    let base = class _Combined extends baseClass {
        constructor (...args) {
            super(...args)
            mixins.forEach((mixin) => {
                mixin.prototype.initializer.call(this)
            })
        }
    }
    let copyProps = (target, source) => {
        Object.getOwnPropertyNames(source)
            .concat(Object.getOwnPropertySymbols(source))
            .forEach((prop) => {
            if (prop.match(/^(?:constructor|prototype|arguments|caller|name|bind|call|apply|toString|length)$/))
                return
            Object.defineProperty(target, prop, Object.getOwnPropertyDescriptor(source, prop))
        })
    }
    mixins.forEach((mixin) => {
        copyProps(base.prototype, mixin.prototype)
        copyProps(base, mixin)
    })
    return base
}

class Colored {
    initializer ()     { this._color = "white" }
    get color ()       { return this._color }
    set color (v)      { this._color = v }
}

class ZCoord {
    initializer ()     { this._z = 0 }
    get z ()           { return this._z }
    set z (v)          { this._z = v }
}

class Shape {
    constructor (x, y) { this._x = x; this._y = y }
    get x ()           { return this._x }
    set x (v)          { this._x = v }
    get y ()           { return this._y }
    set y (v)          { this._y = v }
}

class Rectangle extends aggregation(Shape, Colored, ZCoord) {}

var rect = new Rectangle(7, 42)
rect.z     = 1000
rect.color = "red"
console.log(rect.x, rect.y, rect.z, rect.color)
  ''';

  static const BaseClassAccess = r'''
class Shape {
    constructor (id, x, y) {
        this.id = id
        this.move(x, y)
    }
    move (x, y) {
        this.x = x
        this.y = y
    }
    toString () {
        return `Shape(${this.id})`
    }
}
class Rectangle extends Shape {
    constructor (id, x, y, width, height) {
        super(id, x, y)
        this.width = width;
        this.height = height;
    }
    toString () {
        return "Rectangle > " + super.toString()
    }
}
class Circle extends Shape {
    constructor (id, x, y, radius) {
        super(id, x, y)
        this.radius = radius;
    }
    toString () {
        return "Circle > " + super.toString()
    }
}
expect(new Rectangle(1, 0, 0, 100, 200).toString(), 'Rectangle > Shape(1)');
expect(new Circle(2, 0, 0, 100).toString(), 'Circle > Shape(2)');
  ''';

  static const StaticMembers = r'''
class Shape {
    constructor (id, x, y) {
        this.id = id
        this.move(x, y)
    }
    move (x, y) {
        this.x = x
        this.y = y
    }
}
class Rectangle extends Shape {
    constructor (id, x, y, width, height) {
        super(id, x, y)
        this.width = width;
        this.height = height;
    }
    static defaultRectangle () {
        return new Rectangle("default", 0, 0, 100, 100)
    }
}
class Circle extends Shape {
    constructor (id, x, y, radius) {
        super(id, x, y)
        this.radius = radius;
    }
    static defaultCircle () {
        return new Circle("default", 0, 0, 100)
    }
}
var defRectangle = Rectangle.defaultRectangle()
var defCircle    = Circle.defaultCircle()
expect(defRectangle.width, 100);
expect(defCircle.radius, 100);
  ''';

  static const GetterSetter = r'''
class Rectangle {
    constructor (width, height) {
        this._width  = width
        this._height = height
    }
    set width  (width)  { this._width = width               }
    get width  ()       { return this._width                }
    set height (height) { this._height = height             }
    get height ()       { return this._height               }
    get area   ()       { return this._width * this._height }
}
var r = new Rectangle(50, 20)
expect(r.area, 1000)
  ''';

  static const SymbolType = r'''
expect(Symbol("foo") !== Symbol("foo"), true);
const foo = Symbol()
const bar = Symbol()
expect(typeof foo, "symbol")
expect(typeof bar, "symbol")
let obj = {}
obj[foo] = "foo"
obj[bar] = "bar"
JSON.stringify(obj) // {}
Object.keys(obj) // []
expect(Object.getOwnPropertyNames(obj), [])
expect(Object.getOwnPropertySymbols(obj), [foo, bar])
  ''';

  static const GlobalSymbols = r'''
expect(Symbol.for("app.foo") === Symbol.for("app.foo"), true)
const foo = Symbol.for("app.foo")
const bar = Symbol.for("app.bar")
expect(Symbol.keyFor(foo), "app.foo")
expect(Symbol.keyFor(bar), "app.bar")
expect(typeof foo, "symbol")
expect(typeof bar, "symbol")
let obj = {}
obj[foo] = "foo"
obj[bar] = "bar"
expect(JSON.stringify(obj), '{}')
expect(Object.keys(obj), [])
expect(Object.getOwnPropertyNames(obj), [])
expect(Object.getOwnPropertySymbols(obj), [foo, bar])
  ''';

  static const IteratorAndForOfOperator = r'''
let fibonacci = {
    [Symbol.iterator]() {
        let pre = 0, cur = 1
        return {
           next () {
               [ pre, cur ] = [ cur, pre + cur ]
               return { done: false, value: cur }
           }
        }
    }
}
var result = [];
for (let n of fibonacci) {
    if (n > 10)
        break
    result.push(n)
}
expect(result, [1, 2, 3, 5, 8])
  ''';

  static const GeneratorFunctionAndIteratorProtocol = r'''
let fibonacci = {
    *[Symbol.iterator]() {
        let pre = 0, cur = 1
        for (;;) {
            [ pre, cur ] = [ cur, pre + cur ]
            yield cur
        }
    }
}
var result = [];
for (let n of fibonacci) {
    if (n > 10)
        break
    result.push(n)
}
expect(result, [1, 2, 3, 5, 8])
  ''';

  static const GeneratorFunctionDirectUse = r'''
function* range (start, end, step) {
    while (start < end) {
        yield start
        start += step
    }
}
var result = [];
for (let i of range(0, 10, 2)) {
    result.push(i)
}
expect(result, [0, 2, 4, 6, 8])
  ''';

  static const GeneratorMatching = r'''
let fibonacci = function* (numbers) {
    let pre = 0, cur = 1
    while (numbers-- > 0) {
        [ pre, cur ] = [ cur, pre + cur ]
        yield cur
    }
}

var result = [];
for (let n of fibonacci(10))
    result.push(n)
expect(result, [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]);
let numbers = [ ...fibonacci(10) ]
expect(numbers, [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]);

let [ n1, n2, n3, ...others ] = fibonacci(10)
expect(n1, 1);
expect(n2, 2);
expect(n3, 3);
expect(others, [5, 8, 13, 21, 34, 55, 89]);
  ''';

  static const GeneratorControlFlow = r'''
//  generic asynchronous control-flow driver
function async (proc, ...params) {
    let iterator = proc(...params)
    return new Promise((resolve, reject) => {
        let loop = (value) => {
            let result
            try {
                result = iterator.next(value)
            }
            catch (err) {
                reject(err)
            }
            if (result.done)
                resolve(result.value)
            else if (   typeof result.value      === "object"
                     && typeof result.value.then === "function")
                result.value.then((value) => {
                    loop(value)
                }, (err) => {
                    reject(err)
                })
            else
                loop(result.value)
        }
        loop()
    })
}

//  application-specific asynchronous builder
function makeAsync (text, after) {
    return new Promise((resolve, reject) => {
        setTimeout(() => resolve(text), after)
    })
}

(async function() {
//  application-specific asynchronous procedure
var actual = await async(function* (greeting) {
    let foo = yield makeAsync("foo", 300)
    let bar = yield makeAsync("bar", 200)
    let baz = yield makeAsync("baz", 100)
    return `${greeting} ${foo} ${bar} ${baz}`
}, "Hello")
expect(actual, "Hello foo bar baz");
console.log(actual);
}())
  ''';

  static const GeneratorMethods = r'''
class Clz {
    * bar () {
    }
}
let Obj = {
    * foo () {
    }
}
  ''';

  static const SetDataStructure = r'''
let s = new Set()
s.add("hello").add("goodbye").add("hello")
expect(s.size, 2)
expect(s.has("hello"), true)
var actual = [];
for (let key of s.values()) // insertion order
    actual.push(key)
expect(actual, ['hello', 'goodbye']);
  ''';

  static const MapDataStructure = r'''
let m = new Map()
let s = Symbol()
m.set("hello", 42)
m.set(s, 34)
expect(m.get(s), 34)
expect(m.size, 2)
var actual = [];
for (let [ key, val ] of m.entries())
    actual.push([key, val])
expect(actual, [['hello', 42], [s, 34]]);
  ''';

  static const WeakLinkDataStructures = r'''
let isMarked     = new WeakSet()
let attachedData = new WeakMap()

class Node {
    constructor (id)   { this.id = id                  }
    mark        ()     { isMarked.add(this)            }
    unmark      ()     { isMarked.delete(this)         }
    marked      ()     { return isMarked.has(this)     }
    set data    (data) { attachedData.set(this, data)  }
    get data    ()     { return attachedData.get(this) }
}

let foo = new Node("foo")

expect(JSON.stringify(foo), '{"id":"foo"}')
foo.mark()
foo.data = "bar"
expect(foo.data, "bar")
expect(JSON.stringify(foo), '{"id":"foo"}')

expect(isMarked.has(foo), true)
expect(attachedData.has(foo), true)
foo = null  /* remove only reference to foo */
expect(attachedData.has(foo), false)
expect(isMarked.has(foo), false)
  ''';

  static const TypedArrays = r'''
//  ES6 class equivalent to the following C structure:
//  struct Example { unsigned long id; char username[16]; float amountDue }
class Example {
    constructor (buffer = new ArrayBuffer(24)) {
        this.buffer = buffer
    }
    set buffer (buffer) {
        this._buffer    = buffer
        this._id        = new Uint32Array (this._buffer,  0,  1)
        this._username  = new Uint8Array  (this._buffer,  4, 16)
        this._amountDue = new Float32Array(this._buffer, 20,  1)
    }
    get buffer ()     { return this._buffer       }
    set id (v)        { this._id[0] = v           }
    get id ()         { return this._id[0]        }
    set username (v)  { this._username[0] = v     }
    get username ()   { return this._username[0]  }
    set amountDue (v) { this._amountDue[0] = v    }
    get amountDue ()  { return this._amountDue[0] }
}

let example = new Example()
example.id = 7
example.username = "John Doe"
example.amountDue = 42.0
  ''';

  static const ObjectPropertyAssignment = r'''
var dest = { quux: 0 }
var src1 = { foo: 1, bar: 2 }
var src2 = { foo: 3, baz: 4 }
Object.assign(dest, src1, src2)
expect(dest.quux, 0)
expect(dest.foo, 3)
expect(dest.bar, 2)
expect(dest.baz, 4)
  ''';

  static const ArrayElementFinding = r'''
expect([ 1, 3, 4, 2 ].find(x => x > 3), 4)
expect([ 1, 3, 4, 2 ].findIndex(x => x > 3), 2)
  ''';

  static const StringRepeating = r'''
expect("foo".repeat(3), 'foofoofoo')
  ''';

  static const StringSearching = r'''
expect("hello".startsWith("ello", 1), true)
expect("hello".endsWith("hell", 4), true)
expect("hello".includes("ell"), true)
expect("hello".includes("ell", 1), true)
expect("hello".includes("ell", 2), false)
  ''';

  static const NumberTypeChecking = r'''
expect(Number.isNaN(42), false)
expect(Number.isNaN(NaN), true)

expect(Number.isFinite(Infinity), false)
expect(Number.isFinite(-Infinity), false)
expect(Number.isFinite(NaN), false)
expect(Number.isFinite(123), true)
  ''';

  static const NumberSafetyChecking = r'''
expect(Number.isSafeInteger(42), true)
expect(Number.isSafeInteger(9007199254740992), false)
  ''';

  static const NumberComparison = r'''
expect(0.1 + 0.2 === 0.3, false)
expect(Math.abs((0.1 + 0.2) - 0.3) < Number.EPSILON, true)
  ''';

  static const NumberTruncation = r'''
expect(Math.trunc(42.7), 42)
expect(Math.trunc( 0.1), 0)
expect(Math.trunc(-0.1), -0)
  ''';

  static const NumberSignDetermination = r'''
expect(Math.sign(7), 1)
expect(Math.sign(0), 0)
expect(Math.sign(-0), -0)
expect(Math.sign(-7), -1)
expect(Math.sign(NaN), NaN)
  ''';

  static const PromiseUsage = r'''
function msgAfterTimeout (msg, who, timeout) {
    return new Promise((resolve, reject) => {
        setTimeout(() => resolve(`${msg} Hello ${who}!`), timeout)
    })
}
(async function() {
var actual = await msgAfterTimeout("", "Foo", 100).then((msg) =>
    msgAfterTimeout(msg, "Bar", 200)
).then((msg) => `done after 300ms:${msg}`)
console.log(actual);
expect(actual, 'done after 300ms: Hello Foo! Hello Bar!')
}())
  ''';

  static const PromiseCombination = r'''
function fetchAsync (url, timeout, onData, onError) {
    setTimeout(function() {
      onData(url.substring(url.lastIndexOf('/') + 1));
    }, timeout);
}
let fetchPromised = (url, timeout) => {
    return new Promise((resolve, reject) => {
        fetchAsync(url, timeout, resolve, reject)
    })
};
(async function() {
var actual = await Promise.all([
    fetchPromised("https://backend/foo.txt", 500),
    fetchPromised("https://backend/bar.txt", 500),
    fetchPromised("https://backend/baz.txt", 500)
]).then((data) => {
    let [ foo, bar, baz ] = data
    return `success: foo=${foo} bar=${bar} baz=${baz}`
}, (err) => {
    console.log(`error: ${err}`)
});
console.log(actual);
expect(actual, 'success: foo=foo.txt bar=bar.txt baz=baz.txt');
}());
  ''';

  static const PromiseCombinationSimple = r'''
(async function() {
var actual = await Promise.all([
    new Promise((resolve, reject) => resolve(1)),
    new Promise((resolve, reject) => resolve(2)),
    new Promise((resolve, reject) => resolve(3)),
]);
console.log(actual);
expect(actual, [1, 2, 3]);
}());
  ''';

  static const Proxying = r'''
let target = {
    foo: "Welcome, foo"
}
let proxy = new Proxy(target, {
    get (receiver, name) {
        return name in receiver ? receiver[name] : `Hello, ${name}`
    }
})
expect(proxy.foo, "Welcome, foo")
expect(proxy.world, "Hello, world")
  ''';

  static const Reflection = r'''
let obj = { a: 1 }
Object.defineProperty(obj, "b", { value: 2 })
obj[Symbol.for("c")] = 3;
expect(Reflect.ownKeys(obj), [ "a", "b", Symbol.for("c") ])
  ''';

  static const Collation = r'''
// in German,  "ä" sorts with "a"
// in Swedish, "ä" sorts after "z"
var list = [ "ä", "a", "z" ]
var l10nDE = new Intl.Collator("de")
var l10nSV = new Intl.Collator("sv")
expect(l10nDE.compare("ä", "z"), -1)
expect(l10nSV.compare("ä", "z"), +1)
expect(list.sort(l10nDE.compare), [ "a", "ä", "z" ])
expect(list.sort(l10nSV.compare), [ "a", "z", "ä" ])
  ''';

  static const NumberFormatting = r'''
var l10nEN = new Intl.NumberFormat("en-US")
var l10nDE = new Intl.NumberFormat("de-DE")
expect(l10nEN.format(1234567.89), "1,234,567.89")
expect(l10nDE.format(1234567.89), "1.234.567,89")
  ''';

  static const ConcurrencyFormatting = r'''
var l10nUSD = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" })
var l10nGBP = new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" })
var l10nEUR = new Intl.NumberFormat("de-DE", { style: "currency", currency: "EUR" })
expect(l10nUSD.format(100200300.40), "$100,200,300.40")
expect(l10nGBP.format(100200300.40), "£100,200,300.40")
expect(l10nEUR.format(100200300.40), "100.200.300,40 €")
  ''';

  static const DateAndTimeFormatting = r'''
var l10nEN = new Intl.DateTimeFormat("en-US")
var l10nDE = new Intl.DateTimeFormat("de-DE")
expect(l10nEN.format(new Date("2015-01-02")), "1/2/2015")
expect(l10nDE.format(new Date("2015-01-02")), "2.1.2015")
  ''';
}