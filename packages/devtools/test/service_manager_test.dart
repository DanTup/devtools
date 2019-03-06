// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:devtools/src/eval_on_dart_library.dart';
import 'package:devtools/src/globals.dart';
import 'package:devtools/src/service_extensions.dart' as extensions;
import 'package:devtools/src/service_manager.dart';
import 'package:devtools/src/service_registrations.dart' as registrations;
import 'package:devtools/src/vm_service_wrapper.dart';
import 'package:test/test.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'support/flutter_test_driver.dart';
import 'support/flutter_test_environment.dart';

void main() {
  group('serviceManagerTests', () {
    final FlutterTestEnvironment env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    tearDownAll(() async {
      print('TD1');
      await env.tearDownEnvironment(force: true);
      print('TD2');
    });

    test('vmServiceOpened', () async {
      print('T1');
      await env.setupEnvironment();
      print('T2');

      expect(serviceManager.service, equals(env.service));
      expect(serviceManager.isolateManager, isNotNull);
      expect(serviceManager.serviceExtensionManager, isNotNull);
      expect(serviceManager.isolateManager.isolates, isNotEmpty);

      if (serviceManager.isolateManager.selectedIsolate == null) {
        await serviceManager.isolateManager.onSelectedIsolateChanged
            .firstWhere((ref) => ref != null);
      }

      await env.tearDownEnvironment();

      await endTest('vm service opened');
    });

    test('invalid setBreakpoint throws exception', () async {
      await env.setupEnvironment();
      // Service with more than 1 registration.
      serviceManager.registeredMethodsForService.putIfAbsent(
        'fakeMethod',
        () => ['registration1.fakeMethod', 'registration2.fakeMethod'],
      );
      expect(serviceManager.callService('fakeMethod'), throwsException);

      final Completer<Object> testDone = Completer();
      Object testError;
      runZoned(() {
        Future<void> asyncTestMethod() async {
          // Service with less than 1 registration.
          expect(
              serviceManager.service.addBreakpoint(
                  serviceManager.isolateManager.selectedIsolate.id,
                  'fake-script-id',
                  1),
              throwsException);

          await env.tearDownEnvironment();
        }

        testDone.complete(asyncTestMethod());
      }, onError: ([error]) {
        testError = error;
      });
      await testDone.future;
      // Verify that no uncaught exceptions were thrown in an async manner
      // while running the test.
      // This case catches a regression where a setting a breakpoint at an
      // invalid line would throw an uncaught exception.
      expect(testError, isNull);

      await endTest('invalid bp');
    });

    test('toggle boolean service extension', () async {
      await env.setupEnvironment();

      final extensionName = extensions.debugPaint.extension;
      const evalExpression = 'debugPaintSizeEnabled';
      final library = EvalOnDartLibrary(
        'package:flutter/src/rendering/debug.dart',
        env.service,
      );

      await _verifyExtensionStateOnTestDevice(evalExpression, 'false', library);
      await _verifyInitialExtensionStateInServiceManager(extensionName);

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensionName,
        true,
        true,
      );

      await _verifyExtensionStateOnTestDevice(evalExpression, 'true', library);
      await _verifyExtensionStateInServiceManager(extensionName, true, true);

      await env.tearDownEnvironment();

      await endTest('toggle bool');
    });

    test('toggle String service extension', () async {
      await env.setupEnvironment();

      final extensionName = extensions.togglePlatformMode.extension;
      const evalExpression = 'defaultTargetPlatform.toString()';
      final library = EvalOnDartLibrary(
        'package:flutter/src/foundation/platform.dart',
        env.service,
      );

      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        'TargetPlatform.android',
        library,
      );
      await _verifyInitialExtensionStateInServiceManager(extensionName);

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensionName,
        true,
        'iOS',
      );

      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        'TargetPlatform.iOS',
        library,
      );
      await _verifyExtensionStateInServiceManager(extensionName, true, 'iOS');

      await env.tearDownEnvironment();
      await endTest('toggle string');
    });

    test('toggle numeric service extension', () async {
      print('TG1');
      await env.setupEnvironment();
      print('TG2');

      final extensionName = extensions.slowAnimations.extension;
      const evalExpression = 'timeDilation';
      final library = EvalOnDartLibrary(
        'package:flutter/src/scheduler/binding.dart',
        env.service,
      );

      print('TG3');
      await _verifyExtensionStateOnTestDevice(evalExpression, '1.0', library);
      print('TG4');
      await _verifyInitialExtensionStateInServiceManager(extensionName);
      print('TG5');

      // Enable the service extension via ServiceExtensionManager.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensionName,
        true,
        5.0,
      );
      print('TG6');

      await _verifyExtensionStateOnTestDevice(evalExpression, '5.0', library);
      print('TG7');
      await _verifyExtensionStateInServiceManager(extensionName, true, 5.0);
      print('TG8');

      await env.tearDownEnvironment();
      print('TG9');
      await endTest('toggle numeric');
    });

    test('callService', () async {
      print('CS1');
      await env.setupEnvironment();
      print('CS2');

      final registeredService = serviceManager
              .registeredMethodsForService[registrations.hotReload.service] ??
          const [];
      print('CS3');
      expect(registeredService, isNotEmpty);
      print('CS4');

      await serviceManager.callService(
        registrations.hotReload.service,
        isolateId: serviceManager.isolateManager.selectedIsolate.id,
      );
      print('CS5');

      await env.tearDownEnvironment();
      print('CS6');
      await endTest('callService');
    });

    test('callService throws exception', () async {
      print('CSE1');
      await env.setupEnvironment();
      print('CSE2');

      // Service with less than 1 registration.
      expect(serviceManager.callService('fakeMethod'), throwsException);
      print('CSE3');

      // Service with more than 1 registration.
      serviceManager.registeredMethodsForService.putIfAbsent('fakeMethod',
          () => ['registration1.fakeMethod', 'registration2.fakeMethod']);
      expect(serviceManager.callService('fakeMethod'), throwsException);
      print('CSE4');

      await env.tearDownEnvironment();
      print('CSE5');
      await endTest('callServive exception');
    });

    test('callMulticastService', () async {
      await env.setupEnvironment();

      final registeredService = serviceManager
              .registeredMethodsForService[registrations.hotReload.service] ??
          const [];
      expect(registeredService, isNotEmpty);

      await serviceManager.callMulticastService(
        registrations.hotReload.service,
        isolateId: serviceManager.isolateManager.selectedIsolate.id,
      );

      await env.tearDownEnvironment();

      await endTest('call multicast');
    });

    test('callMulticastService throws exception', () async {
      await env.setupEnvironment();

      expect(serviceManager.callService('fakeMethod'), throwsException);

      await env.tearDownEnvironment();

      await endTest('call multicast exception');
    });

    test('hotReload', () async {
      await env.setupEnvironment();

      await serviceManager.performHotReload();

      await env.tearDownEnvironment();

      await endTest('hot reload');
    });

    // TODO(jacobr): uncomment out the hotRestart tests once
    // https://github.com/flutter/devtools/issues/337 is fixed.
    /*
    test('hotRestart', () async {
      await env.setupEnvironment();

      const evalExpression = 'topLevelFieldForTest';
      final library = EvalOnDartLibrary(
        'package:flutter_app/main.dart',
        env.service,
      );

      // Verify topLevelFieldForTest is false initially.
      final initialResult = await library.eval(evalExpression, isAlive: null);
      expect(initialResult.runtimeType, equals(InstanceRef));
      expect(initialResult.valueAsString, equals('false'));

      // Set field to true by calling the service extension.
      await library.eval('$evalExpression = true', isAlive: null);

      // Verify topLevelFieldForTest is now true.
      final intermediateResult =
          await library.eval(evalExpression, isAlive: null);
      expect(intermediateResult.runtimeType, equals(InstanceRef));
      expect(intermediateResult.valueAsString, equals('true'));

      await serviceManager.performHotRestart();

      /// After the hot restart some existing calls to the vm service may
      /// timeout and that is ok.
      serviceManager.service.doNotWaitForPendingFuturesBeforeExit();

      // Verify topLevelFieldForTest is false again after hot restart.
      final finalResult = await library.eval(evalExpression, isAlive: null);
      expect(finalResult.runtimeType, equals(InstanceRef));
      expect(finalResult.valueAsString, equals('false'));

      await env.tearDownEnvironment();
    });
    */
  }, tags: 'useFlutterSdk', timeout: const Timeout.factor(8));

  group('serviceManagerTests - restoring device-enabled extension:', () {
    FlutterRunTestDriver _flutter;
    String _flutterIsolateId;
    VmServiceWrapper service;

    setUp(() async {
      _flutter = FlutterRunTestDriver(Directory('../../fixtures/flutter_app'));
      await _flutter.run(
          runConfig: const FlutterRunConfiguration(withDebugger: true));
      _flutterIsolateId = await _flutter.getFlutterIsolateId();

      service = _flutter.vmService;
      setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    });

    tearDown(() async {
      await service.allFuturesCompleted.future;
      await _flutter.stop();
    });

    /// Helper method to call an extension on the test device and verify that
    /// the device reflects the new extension state.
    Future<void> _enableExtensionOnTestDevice(
      extensions.ToggleableServiceExtensionDescription extensionDescription,
      Map<String, dynamic> args,
      String evalExpression,
      EvalOnDartLibrary library, {
      String enabledValue,
      String disabledValue,
    }) async {
      enabledValue ??= extensionDescription.enabledValue.toString();
      disabledValue ??= extensionDescription.disabledValue.toString();

      // Verify initial extension state on test device.
      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        disabledValue,
        library,
      );

      // Enable service extension on test device.
      await _flutter.vmService.callServiceExtension(
        extensionDescription.extension,
        isolateId: _flutterIsolateId,
        args: args,
      );

      // Verify extension state after calling the service extension.
      await _verifyExtensionStateOnTestDevice(
        evalExpression,
        enabledValue,
        library,
      );
    }

    test('all extension types', () async {
      // Enable a boolean extension on the test device.
      const boolExtensionDescription = extensions.debugPaint;
      final boolArgs = {'enabled': true};
      const boolEvalExpression = 'debugPaintSizeEnabled';
      final boolLibrary = EvalOnDartLibrary(
        'package:flutter/src/rendering/debug.dart',
        service,
        isolateId: _flutterIsolateId,
      );
      await _enableExtensionOnTestDevice(
        boolExtensionDescription,
        boolArgs,
        boolEvalExpression,
        boolLibrary,
      );

      // Enable a String extension on the test device.
      const stringExtensionDescription = extensions.togglePlatformMode;
      final stringArgs = {'value': 'iOS'};
      const stringEvalExpression = 'defaultTargetPlatform.toString()';
      final stringLibrary = EvalOnDartLibrary(
        'package:flutter/src/foundation/platform.dart',
        service,
        isolateId: _flutterIsolateId,
      );
      await _enableExtensionOnTestDevice(
        stringExtensionDescription,
        stringArgs,
        stringEvalExpression,
        stringLibrary,
        enabledValue: 'TargetPlatform.iOS',
        disabledValue: 'TargetPlatform.android',
      );

      // Enable a numeric extension on the test device.
      const numericExtensionDescription = extensions.slowAnimations;
      final numericArgs = {
        numericExtensionDescription.extension.substring(
                numericExtensionDescription.extension.lastIndexOf('.') + 1):
            numericExtensionDescription.enabledValue
      };
      const numericEvalExpression = 'timeDilation';
      final numericLibrary = EvalOnDartLibrary(
        'package:flutter/src/scheduler/binding.dart',
        service,
        isolateId: _flutterIsolateId,
      );
      await _enableExtensionOnTestDevice(
        numericExtensionDescription,
        numericArgs,
        numericEvalExpression,
        numericLibrary,
      );

      // Open the VmService and verify that the enabled extension states are
      // reflected in [ServiceExtensionManager].
      await serviceManager.vmServiceOpened(
        service,
        onClosed: Completer().future,
      );
      await serviceManager
          .serviceExtensionManager.extensionStatesUpdated.future;

      await _verifyExtensionStateInServiceManager(
        boolExtensionDescription.extension,
        true,
        boolExtensionDescription.enabledValue,
      );
      await _verifyExtensionStateInServiceManager(
        stringExtensionDescription.extension,
        true,
        stringExtensionDescription.enabledValue,
      );
      await _verifyExtensionStateInServiceManager(
        numericExtensionDescription.extension,
        true,
        numericExtensionDescription.enabledValue,
      );
    });
  }, tags: 'useFlutterSdk', timeout: const Timeout.factor(8), skip: true);
}

Future<void> _verifyExtensionStateOnTestDevice(String evalExpression,
    String expectedResult, EvalOnDartLibrary library) async {
  final result = await library.eval(evalExpression, isAlive: null);
  if (result is InstanceRef) {
    expect(result.valueAsString, equals(expectedResult));
  }
}

Future<void> _verifyInitialExtensionStateInServiceManager(
    String extensionName) async {
  // For all service extensions, the initial state in ServiceExtensionManager
  // should be disabled with value null.
  await _verifyExtensionStateInServiceManager(extensionName, false, null);
}

Future<void> _verifyExtensionStateInServiceManager(
    String extensionName, bool enabled, dynamic value) async {
  final StreamSubscription<ServiceExtensionState> stream = serviceManager
      .serviceExtensionManager
      .getServiceExtensionState(extensionName, null);

  final Completer<ServiceExtensionState> stateCompleter = Completer();
  stream.onData((ServiceExtensionState state) {
    stateCompleter.complete(state);
    stream.cancel();
  });

  final ServiceExtensionState state = await stateCompleter.future;
  expect(state.enabled, equals(enabled));
  expect(state.value, equals(value));
}

Future<void> endTest(String name) async {
  print('Test $name has ended... Waiting 30 seconds...');
  await Future.delayed(Duration(seconds: 20));
  print('Done! ($name)');
}
