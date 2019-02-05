import 'package:test/test.dart';

import 'support/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'support/flutter_test_environment.dart';

void main() async {
  group('inspector controller tests', () {
    print('### CONTROLLER: 1');
    FlutterTestEnvironment env;

    tearDown(() async {
      print('### CONTROLLER: 4');
      await env?.tearDownEnvironment();
      print('### CONTROLLER: 5');
    });
    tearDownAll(() async {
      print('### CONTROLLER: 6');
      await env?.tearDownEnvironment(force: true);
      print('### CONTROLLER: 7');
    });

    test('hasServiceMethod', () async {
      env = FlutterTestEnvironment(
        const FlutterRunConfiguration(withDebugger: true),
      );
      print('### CONTROLLER: 2');
      await env.setupEnvironment();
      print('### CONTROLLER: 3');
    });
  });
}
