import 'package:test/test.dart';

import 'support/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'support/flutter_test_environment.dart';

void main() async {
  group('inspector service tests', () {
    print('### SERVICE: 1');
    FlutterTestEnvironment env;

    tearDown(() async {
      print('### SERVICE: 4');
      await env?.tearDownEnvironment();
      print('### SERVICE: 5');
    });
    tearDownAll(() async {
      print('### SERVICE: 6');
      await env?.tearDownEnvironment(force: true);
      print('### SERVICE: 7');
    });

    test('hasServiceMethod', () async {
      env = FlutterTestEnvironment(
        const FlutterRunConfiguration(withDebugger: true),
      );
      print('### SERVICE: 2');
      await env.setupEnvironment();
      print('### SERVICE: 3');
    });
  });
}
