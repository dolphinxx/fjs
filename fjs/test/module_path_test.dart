import 'package:test/test.dart';

void main() {
  List parse(String raw) {
    late String moduleName;
    late List<String> path;
    String? version;
    // paths starts with `.` or `/` will not be parsed.
    if(raw.codeUnitAt(0) == 46 || raw.codeUnitAt(0) == 47) {
      moduleName = raw;
      path = [moduleName];
    } else {
      path = raw.split('/');
      String firstPath = path.first;
      // can have an optional version suffix
      int versionPos = firstPath.indexOf('@');
      if(versionPos > 0) {
        version = firstPath.substring(versionPos + 1);
        path[0] = firstPath.substring(0, versionPos);
      }
      moduleName = path[0];
    }
    return [moduleName, path, version];
  }
  test('no version single path', () {
    List actual = parse('a');
    expect(actual, ['a', ['a'], null]);
  });
  test('no version multiple path', () {
    List actual = parse('a/b/c');
    expect(actual, ['a', ['a', 'b', 'c'], null]);
  });
  test('has version single path', () {
    List actual = parse('a@1.1');
    expect(actual, ['a', ['a'], '1.1']);
  });
  test('has version multiple path', () {
    List actual = parse('a@1.1/b/c');
    expect(actual, ['a', ['a', 'b', 'c'], '1.1']);
  });
  test('start with dot', () {
    List actual = parse('./a/b/c');
    expect(actual, ['./a/b/c', ['./a/b/c'], null]);
  });
  test('start with slash', () {
    List actual = parse('/a/b/c');
    expect(actual, ['/a/b/c', ['/a/b/c'], null]);
  });
}