import 'dart:async';
import 'dart:io';

var _log = [];
// https://stackoverflow.com/questions/14764323/how-do-i-mock-or-verify-a-call-to-print-in-dart-unit-tests/14765018#answer-38709440
void Function() capturePrint(void testFn()) => () {
  var spec = new ZoneSpecification(
      print: (_, __, ___, String msg) {
        // Add to log instead of printing to stdout
        _log.add(msg);
        stdout.writeln(msg);
      }
  );
  return Zone.current.fork(specification: spec).run<void>(testFn);
};

String? consumeLastPrint() {
  return _log.isEmpty ? null : _log.removeLast();
}