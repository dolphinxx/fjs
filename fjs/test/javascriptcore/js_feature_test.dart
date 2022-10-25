import 'package:fjs/javascriptcore/vm.dart';
import 'package:test/test.dart';
import '../tests/js_feature_tests.dart';

void main() {
  group('js_feature', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm();
    });
    tearDown(() {
      vm.dispose();
    });
    test('regex capturing group', () async {
      testRegexCapturingGroup(vm);
    });
    test('JSONStringify', () async {
      testJSONStringify(vm);
    });
  });
  group('ES6', () {
    late JavaScriptCoreVm vm;
    setUp(() {
      vm = JavaScriptCoreVm(disableConsole: false);
      vm.evalCode(JS_EXPECT, filename: 'expect');
    });
    tearDown(() {
      vm.dispose();
    });
    test('ES6 Constants', () {
      vm.evalCode(ES6Features.Constants);
    });
    group('ES6 Scoping', () {
      test('ES6 BlockScopedVariables', () {
        vm.evalCode(ES6Features.BlockScopedVariables);
      });
      test('ES6 BlockScopedFunctions', () {
        vm.evalCode(ES6Features.BlockScopedFunctions);
      }, skip: 'JavaScriptCore: Later redeclared function overwrites previously declared one even called before it was declared.');
    });
    group('ES6 Arrow Functions', () {
      test('ES6 ArrowExpressBodies', () {
        vm.evalCode(ES6Features.ArrowExpressBodies);
      });
      test('ES6 ArrowStatementBodies', () {
        vm.evalCode(ES6Features.ArrowStatementBodies);
      });
      test('ES6 ArrowLexicalThis', () {
        vm.evalCode(ES6Features.ArrowLexicalThis);
      });
    });
    group('ES6 Extended Parameter Handling', () {
      test('ES6 DefaultParameterValues', () {
        vm.evalCode(ES6Features.DefaultParameterValues);
      });
      test('ES6 RestParameter', () {
        vm.evalCode(ES6Features.RestParameter);
      });
      test('ES6 SpreadOperator', () {
        vm.evalCode(ES6Features.SpreadOperator);
      });
    });
    group('ES6 Template Literals', () {
      test('ES6 StringInterpolation', () {
        vm.evalCode(ES6Features.StringInterpolation);
      });
      test('ES6 CustomInterpolation', () {
        vm.evalCode(ES6Features.CustomInterpolation);
      });
      test('ES6 RawStringAccess', () {
        vm.evalCode(ES6Features.RawStringAccess);
      });
    });
    group('ES6 Extended Literals', () {
      test('ES6 BinaryAndOctalLiteral', () {
        vm.evalCode(ES6Features.BinaryAndOctalLiteral);
      });
      test('ES6 UnicodeStringAndRegExpLiteral', () {
        vm.evalCode(ES6Features.UnicodeStringAndRegExpLiteral);
      });
    });
    group('ES6 Enhanced Regular Expression', () {
      test('ES6 RegularExpressionStickyMatching', () {
        vm.evalCode(ES6Features.RegularExpressionStickyMatching);
      });
    });
    group('ES6 Enhanced Object Properties', () {
      test('ES6 PropertyShorthand', () {
        vm.evalCode(ES6Features.PropertyShorthand);
      });
      test('ES6 ComputedPropertyNames', () {
        vm.evalCode(ES6Features.ComputedPropertyNames);
      });
      test('ES6 MethodProperties', () {
        vm.evalCode(ES6Features.MethodProperties);
      });
    });
    group('ES6 Destructuring Assignment', () {
      test('ES6 ArrayMatching', () {
        vm.evalCode(ES6Features.ArrayMatching);
      });
      test('ES6 ObjectMatchingShorthandNotation', () {
        vm.evalCode(ES6Features.ObjectMatchingShorthandNotation);
      });
      test('ES6 ObjectDeepMatching', () {
        vm.evalCode(ES6Features.ObjectDeepMatching);
      });
      test('ES6 ObjectAndArrayMatchingDefaultValues', () {
        vm.evalCode(ES6Features.ObjectAndArrayMatchingDefaultValues);
      });
      test('ES6 ParameterContextMatching', () {
        vm.evalCode(ES6Features.ParameterContextMatching);
      });
      test('ES6 FailSoftDestructuringOptionallyWithDefaults', () {
        vm.evalCode(ES6Features.FailSoftDestructuringOptionallyWithDefaults);
      });
    });
    group('ES6 Modules', () {
      test('ES6 ValueExportAndImport', () {
        vm.evalCode(ES6Features.ValueExport);
        vm.evalCode(ES6Features.ValueImport);
      });
      test('ES6 DefaultAndWildcard', () {
        vm.evalCode(ES6Features.DefaultAndWildcardExport);
        vm.evalCode(ES6Features.DefaultAndWildcardImport);
      });
    }, skip: 'JavaScriptCore: not yet implemented');
    group('ES6 Classes', () {
      test('ES6 ClassDefinitionAndInheritance', () {
        vm.evalCode(ES6Features.ClassDefinitionAndInheritance);
      });
      test('ES6 ClassInheritanceFromExpressions', () {
        vm.evalCode(ES6Features.ClassInheritanceFromExpressions);
      });
      test('ES6 BaseClassAccess', () {
        vm.evalCode(ES6Features.BaseClassAccess);
      });
      test('ES6 StaticMembers', () {
        vm.evalCode(ES6Features.StaticMembers);
      });
      test('ES6 GetterSetter', () {
        vm.evalCode(ES6Features.GetterSetter);
      });
    });
    group('ES6 Symbol Type', () {
      test('ES6 SymbolType', () {
        vm.evalCode(ES6Features.SymbolType);
      });
      test('ES6 GlobalSymbols', () {
        vm.evalCode(ES6Features.GlobalSymbols);
      });
    });
    group('ES6 Iterators', () {
      test('ES6 IteratorAndForOfOperator', () {
        vm.evalCode(ES6Features.IteratorAndForOfOperator);
      });
    });
    group('ES6 Generators', () {
      test('ES6 GeneratorFunctionAndIteratorProtocol', () {
        vm.evalCode(ES6Features.GeneratorFunctionAndIteratorProtocol);
      });
      test('ES6 GeneratorFunctionDirectUse', () {
        vm.evalCode(ES6Features.GeneratorFunctionDirectUse);
      });
      test('ES6 GeneratorMatching', () {
        vm.evalCode(ES6Features.GeneratorMatching);
      });
      test('ES6 GeneratorControlFlow', () async {
        vm.startEventLoop();
        await Future.value(vm.jsToDart(vm.evalCode(ES6Features.GeneratorControlFlow)));
        print('success');
      });
      test('ES6 GeneratorMethods', () {
        vm.evalCode(ES6Features.GeneratorMethods);
        print('success');
      });
    });
    group('ES6 Map/Set & WeakMap/WeakSet', () {
      test('ES6 SetDataStructure', () {
        vm.evalCode(ES6Features.SetDataStructure);
      });
      test('ES6 MapDataStructure', () {
        vm.evalCode(ES6Features.MapDataStructure);
      });
      test('ES6 WeakLinkDataStructures', () {
        vm.evalCode(ES6Features.WeakLinkDataStructures);
      });
    });
    group('ES6 Typed Arrays', () {
      test('ES6 TypedArrays', () {
        vm.evalCode(ES6Features.TypedArrays);
      });
    });
    group('ES6 New Built-In Methods', () {
      test('ES6 ObjectPropertyAssignment', () {
        vm.evalCode(ES6Features.ObjectPropertyAssignment);
      });
      test('ES6 ArrayElementFinding', () {
        vm.evalCode(ES6Features.ArrayElementFinding);
      });
      test('ES6 StringRepeating', () {
        vm.evalCode(ES6Features.StringRepeating);
      });
      test('ES6 StringSearching', () {
        vm.evalCode(ES6Features.StringSearching);
      });
      test('ES6 NumberTypeChecking', () {
        vm.evalCode(ES6Features.NumberTypeChecking);
      });
      test('ES6 NumberSafetyChecking', () {
        vm.evalCode(ES6Features.NumberSafetyChecking);
      });
      test('ES6 NumberComparison', () {
        vm.evalCode(ES6Features.NumberComparison);
      });
      test('ES6 NumberTruncation', () {
        vm.evalCode(ES6Features.NumberTruncation);
      });
      test('ES6 NumberSignDetermination', () {
        vm.evalCode(ES6Features.NumberSignDetermination);
      });
    });
    group('ES6 Promises', () {
      test('ES6 PromiseUsage', () async {
        vm.startEventLoop();
        await Future.value(vm.jsToDart(vm.evalCode(ES6Features.PromiseUsage)));
      });
      test('ES6 PromiseCombination', () async {
        vm.startEventLoop();
        await Future.value(vm.jsToDart(vm.evalCode(ES6Features.PromiseCombination)));
      });
    });
    group('ES6 Meta-Programming', () {
      test('ES6 Proxying', () {
        vm.evalCode(ES6Features.Proxying);
      });
      test('ES6 for-in Proxying', () {
        vm.evalCode(ES6Features.ProxyingForIn);
      });
      test('ES6 Reflection', () {
        vm.evalCode(ES6Features.Reflection);
      });
    });
    group('ES6 Internationalization & Localization', () {
      // see https://test262.report/browse/intl402?date=2020-12-16&engines=javascriptcore%2Cqjs
      test('ES6 Collation', () {
        vm.evalCode(ES6Features.Collation);
      });
      test('ES6 NumberFormatting', () {
        vm.evalCode(ES6Features.NumberFormatting);
      });
      test('ES6 ConcurrencyFormatting', () {
        vm.evalCode(ES6Features.ConcurrencyFormatting);
      });
      test('ES6 DateAndTimeFormatting', () {
        vm.evalCode(ES6Features.DateAndTimeFormatting);
      });
    });
  });
}