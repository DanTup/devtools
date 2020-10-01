// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:provider/provider.dart';

import '../devtools.dart' as devtools;
import 'analytics/analytics_stub.dart'
    if (dart.library.html) 'analytics/analytics.dart' as ga;
import 'analytics/constants.dart';
import 'analytics/provider.dart';
import 'app_size/app_size_controller.dart';
import 'app_size/app_size_screen.dart';
import 'common_widgets.dart';
import 'config_specific/ide_theme/ide_theme.dart';
import 'debugger/debugger_controller.dart';
import 'debugger/debugger_screen.dart';
import 'dialogs.dart';
import 'framework/framework_core.dart';
import 'globals.dart';
import 'initializer.dart';
import 'inspector/inspector_screen.dart';
import 'landing_screen.dart';
import 'logging/logging_controller.dart';
import 'logging/logging_screen.dart';
import 'memory/memory_controller.dart';
import 'memory/memory_screen.dart';
import 'network/network_controller.dart';
import 'network/network_screen.dart';
import 'notifications.dart';
import 'performance/performance_controller.dart';
import 'performance/performance_screen.dart';
import 'preferences.dart';
import 'scaffold.dart';
import 'screen.dart';
import 'snapshot_screen.dart';
import 'theme.dart';
import 'timeline/timeline_controller.dart';
import 'timeline/timeline_screen.dart';
import 'ui/service_extension_widgets.dart';
import 'utils.dart';

const homeScreenId = '';
const snapshotScreenId = 'snapshot';
const appSizeScreenId = 'app-size';

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  const DevToolsApp(
    this.screens,
    this.preferences,
    this.ideTheme,
    this.analyticsProvider,
  );

  final List<DevToolsScreen> screens;
  final PreferencesController preferences;
  final IdeTheme ideTheme;
  final AnalyticsProvider analyticsProvider;

  @override
  State<DevToolsApp> createState() => DevToolsAppState();

  static DevToolsAppState of(BuildContext context) {
    return context.findAncestorStateOfType<DevToolsAppState>();
  }
}

/// Initializer for the [FrameworkCore] and the app's navigation.
///
/// This manages the route generation, and marshalls URL query parameters into
/// flutter route parameters.
// TODO(https://github.com/flutter/devtools/issues/1146): Introduce tests that
// navigate the full app.
class DevToolsAppState extends State<DevToolsApp> {
  List<Screen> get _screens => widget.screens.map((s) => s.screen).toList();

  PreferencesController get preferences => widget.preferences;
  IdeTheme get ideTheme => widget.ideTheme;

  @override
  void initState() {
    super.initState();

    serviceManager.isolateManager.onSelectedIsolateChanged.listen((_) {
      setState(() {
        _clearCachedRoutes();
      });
    });
  }

  @override
  void didUpdateWidget(DevToolsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clearCachedRoutes();
  }

  /// Gets the page for a given page/path and args.
  Page _getPage(BuildContext context, String page, Map<String, String> args) {
    print('Getting pages for "$page" / $args');
    // Provide the appropriate page route.
    if (pages.containsKey(page)) {
      Widget widget = pages[page](
        context,
        args,
      );
      // assert(() {
      //   widget = _AlternateCheckedModeBanner(
      //     builder: (context) => pages[page](
      //       context,
      //       args,
      //     ),
      //   );
      //   return true;
      // }());
      return MaterialPage(child: widget);
    }

    // Return a page not found.
    return MaterialPage(
      child: DevToolsScaffold.withChild(
        key: const Key('not-found'),
        child: CenteredMessage("'$page' not found."),
        ideTheme: ideTheme,
        analyticsProvider: widget.analyticsProvider,
      ),
    );
  }

  Widget _buildTabbedScreen(BuildContext context, Map<String, String> params) {
    print('Building tabbed screen! $params');
    final appServiceUrl = params['uri'];

    // Always return the landing screen if there's no VM service URI.
    if (appServiceUrl?.isEmpty ?? true) {
      print('No URL, so returning landing screen...');
      return DevToolsScaffold.withChild(
        key: const Key('landing'),
        child: LandingScreenBody(),
        ideTheme: ideTheme,
        analyticsProvider: widget.analyticsProvider,
        actions: [
          OpenSettingsAction(),
          OpenAboutAction(),
        ],
      );
    }

    // TODO(dantup): We should be able simplify this a little, removing params['page']
    // and only supporting /inspector (etc.) instead of also &page=inspector if
    // all IDEs switch over to those URLs.
    final page = params['page'];
    final embed = params['embed'] == 'true';
    print('Returning initializer!');
    return Initializer(
      url: appServiceUrl,
      allowConnectionScreenOnDisconnect: !embed,
      builder: (_) {
        final tabs = embed && page != null
            ? _visibleScreens().where((p) => p.screenId == page).toList()
            : _visibleScreens();
        if (tabs.isEmpty) {
          return DevToolsScaffold.withChild(
            child: CenteredMessage(
                'The "$page" screen is not available for this application.'),
            ideTheme: ideTheme,
            analyticsProvider: widget.analyticsProvider,
          );
        }
        return _providedControllers(
          child: DevToolsScaffold(
            embed: embed,
            ideTheme: ideTheme,
            initialPage: page,
            tabs: tabs,
            analyticsProvider: widget.analyticsProvider,
            actions: [
              // TODO(https://github.com/flutter/devtools/issues/1941)
              if (serviceManager.connectedApp.isFlutterAppNow) ...[
                HotReloadButton(),
                HotRestartButton(),
              ],
              OpenSettingsAction(),
              OpenAboutAction(),
            ],
          ),
        );
      },
    );
  }

  /// The pages that the app exposes.
  Map<String, UrlParametersBuilder> get pages {
    return _routes ??= {
      homeScreenId: _buildTabbedScreen,
      for (final screen in widget.screens)
        screen.screen.screenId: _buildTabbedScreen,
      snapshotScreenId: (_, args) {
        final snapshotArgs = SnapshotArguments.fromArgs(args);
        return DevToolsScaffold.withChild(
          key: const Key('snapshot'),
          analyticsProvider: widget.analyticsProvider,
          child: _providedControllers(
            offline: true,
            child: SnapshotScreenBody(snapshotArgs, _screens),
          ),
          ideTheme: ideTheme,
        );
      },
      appSizeScreenId: (_, __) {
        return DevToolsScaffold.withChild(
          key: const Key('appsize'),
          analyticsProvider: widget.analyticsProvider,
          child: _providedControllers(
            child: const AppSizeBody(),
          ),
          ideTheme: ideTheme,
          actions: [
            OpenSettingsAction(),
            OpenAboutAction(),
          ],
        );
      },
    };
  }

  Map<String, UrlParametersBuilder> _routes;

  void _clearCachedRoutes() {
    _routes = null;
  }

  List<Screen> _visibleScreens() => _screens.where(shouldShowScreen).toList();

  Widget _providedControllers({@required Widget child, bool offline = false}) {
    final _providers = widget.screens
        .where((s) =>
            s.createController != null && (offline ? s.supportsOffline : true))
        .map((s) => s.controllerProvider)
        .toList();

    return MultiProvider(
      providers: _providers,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.preferences.darkModeTheme,
      builder: (context, value, _) {
        return MaterialApp.router(
          title: 'Dart DevTools',
          debugShowCheckedModeBanner: false,
          theme: themeFor(isDarkTheme: value, ideTheme: ideTheme),
          builder: (context, child) => Notifications(child: child),
          routerDelegate: DevToolsRouterDelegate(_getPage),
          routeInformationParser: DevToolsRouteInformationParser(),
        );
      },
    );
  }
}

class DevToolsRouterDelegate extends RouterDelegate<DevToolsRouteConfiguration>
    with
        ChangeNotifier,
        PopNavigatorRouterDelegateMixin<DevToolsRouteConfiguration> {
  DevToolsRouterDelegate(this._getPage)
      : navigatorKey = GlobalKey<NavigatorState>();

  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final Page Function(BuildContext, String, Map<String, String>) _getPage;
  final routes = ListQueue<DevToolsRouteConfiguration>();

  void pushScreenIfNotCurrent(String screen, [Map<String, String> updateArgs]) {
    print('Attempting to push screen "$screen" $updateArgs');
    final screenChanged = screen != currentConfiguration.screen;
    final argsChanged = !mapEquals(
      {...currentConfiguration.args, ...?updateArgs},
      currentConfiguration.args,
    );
    if (!screenChanged && !argsChanged) {
      print('Nothing changed, so skipping');
      return;
    }

    routes.add(DevToolsRouteConfiguration(
        screen, {...currentConfiguration.args, ...?updateArgs}));
    // Needs to notify the router that the state has changed.
    notifyListeners();
  }

  void updateArgsIfNotCurrent(Map<String, String> updateArgs) {
    print('Attempting to update args $updateArgs');
    final argsChanged = !mapEquals(
      {...currentConfiguration.args, ...?updateArgs},
      currentConfiguration.args,
    );
    if (!argsChanged) {
      print('Nothing changed, so skipping');
      return;
    }

    print('pushing screen with replaced args $updateArgs');
    routes.add(DevToolsRouteConfiguration(
      currentConfiguration.screen,
      {...currentConfiguration.args, ...updateArgs},
    ));
    // Needs to notify the router that the state has changed.
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final routeConfig = routes.last;
    final screen = routeConfig.screen;
    final args = routeConfig.args ?? {};

    print('RouterDelegate is building! $screen / $args');

    return Navigator(
      key: navigatorKey,
      pages: [_getPage(context, screen, args)],
      onPopPage: (route, result) => popPage(),
    );
  }

  bool popPage() {
    print('RouterDelegate is popping page');

    if (routes.length <= 1) {
      print('skipping popRoute');
      return false;
    }
    print('removing last route');
    routes.removeLast();
    notifyListeners();
    return true;
  }

  @override
  Future<void> setNewRoutePath(DevToolsRouteConfiguration configuration) {
    print(
        'setting new route path "${configuration?.screen}" / ${configuration?.args}');
    routes.add(configuration);
    return SynchronousFuture<void>(null);
  }

  @override
  DevToolsRouteConfiguration get currentConfiguration {
    if (routes.isEmpty) {
      print('returning null as current config');
      return null;
    }
    print('returning "${routes.last}" as current config');
    return routes.last;
  }
}

class DevToolsRouteInformationParser
    extends RouteInformationParser<DevToolsRouteConfiguration> {
  @override
  Future<DevToolsRouteConfiguration> parseRouteInformation(
      RouteInformation routeInformation) {
    print('parsing route: ${routeInformation.location}');
    return SynchronousFuture<DevToolsRouteConfiguration>(
        DevToolsRouteConfiguration.fromRouteInformation(routeInformation));
  }

  @override
  RouteInformation restoreRouteInformation(
      DevToolsRouteConfiguration configuration) {
    print('restoring route: ${configuration?.screen} : ${configuration?.args}');
    return configuration.toRouteInformation();
  }
}

class DevToolsRouteConfiguration {
  DevToolsRouteConfiguration(this.screen, this.args);
  final String screen;
  final Map<String, String> args;

  static DevToolsRouteConfiguration fromRouteInformation(
      RouteInformation routeInformation) {
    final uri = Uri.parse(routeInformation.location);
    return DevToolsRouteConfiguration(
        uri.path.substring(1), uri.queryParameters);
  }

  RouteInformation toRouteInformation() {
    final path = '/${screen ?? ''}';
    final params = (args?.length ?? 0) != 0 ? args : null;
    return RouteInformation(
        location: Uri(path: path, queryParameters: params).toString());
  }
}

/// DevTools screen wrapper that is responsible for creating and providing the
/// screen's controller, as well as enabling offline support.
///
/// [C] corresponds to the type of the screen's controller, which is created by
/// [createController] and provided by [controllerProvider].
class DevToolsScreen<C> {
  const DevToolsScreen(
    this.screen, {
    @required this.createController,
    this.supportsOffline = false,
  });

  final Screen screen;

  /// Responsible for creating the controller for this screen, if non-null.
  ///
  /// The controller will then be provided via [controllerProvider], and
  /// widgets depending on this controller can access it by calling
  /// `Provider<C>.of(context)`.
  ///
  /// If null, [screen] will be responsible for creating and maintaining its own
  /// controller.
  final C Function() createController;

  /// Whether this screen has implemented offline support.
  ///
  /// Defaults to false.
  final bool supportsOffline;

  Provider<C> get controllerProvider {
    assert(createController != null);
    return Provider<C>(create: (_) => createController());
  }
}

/// A [WidgetBuilder] that takes an additional map of URL query parameters and
/// args.
typedef UrlParametersBuilder = Widget Function(
  BuildContext,
  Map<String, String>,
);

/// Displays the checked mode banner in the bottom end corner instead of the
/// top end corner.
///
/// This avoids issues with widgets in the appbar being hidden by the banner
/// in a web or desktop app.
class _AlternateCheckedModeBanner extends StatelessWidget {
  const _AlternateCheckedModeBanner({Key key, this.builder}) : super(key: key);
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: 'DEBUG',
      textDirection: TextDirection.ltr,
      location: BannerLocation.topStart,
      child: Builder(
        builder: builder,
      ),
    );
  }
}

class OpenAboutAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ActionButton(
      tooltip: 'About DevTools',
      child: InkWell(
        onTap: () async {
          unawaited(showDialog(
            context: context,
            builder: (context) => DevToolsAboutDialog(),
          ));
        },
        child: Container(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
          alignment: Alignment.center,
          child: const Icon(
            Icons.help_outline,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

class OpenSettingsAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ActionButton(
      tooltip: 'Settings',
      child: InkWell(
        onTap: () async {
          unawaited(showDialog(
            context: context,
            builder: (context) => SettingsDialog(),
          ));
        },
        child: Container(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
          alignment: Alignment.center,
          child: const Icon(
            Icons.settings,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

class DevToolsAboutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DevToolsDialog(
      title: dialogTitleText(theme, 'About DevTools'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aboutDevTools(context),
          const SizedBox(height: defaultSpacing),
          ...dialogSubHeader(theme, 'Feedback'),
          Wrap(
            children: [
              const Text('Encountered an issue? Let us know at '),
              _createFeedbackLink(context),
              const Text('.')
            ],
          ),
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }

  Widget _aboutDevTools(BuildContext context) {
    return const SelectableText('DevTools version ${devtools.version}');
  }

  Widget _createFeedbackLink(BuildContext context) {
    const urlPath = 'github.com/flutter/devtools/issues';
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        ga.select(devToolsMain, feedback);

        const reportIssuesUrl = 'https://$urlPath';
        await launchUrl(reportIssuesUrl, context);
      },
      child: Text(urlPath, style: linkTextStyle(colorScheme)),
    );
  }
}

// TODO(devoncarew): Add an analytics setting.

class SettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final preferences = DevToolsApp.of(context).preferences;

    return DevToolsDialog(
      title: dialogTitleText(Theme.of(context), 'Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              preferences.toggleDarkModeTheme(!preferences.darkModeTheme.value);
            },
            child: Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: preferences.darkModeTheme,
                  builder: (context, value, _) {
                    return Checkbox(
                      value: value,
                      onChanged: (bool value) {
                        preferences.toggleDarkModeTheme(value);
                      },
                    );
                  },
                ),
                const Text('Use a dark theme'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}

/// Screens to initialize DevTools with.
///
/// If the screen depends on a provided controller, the provider should be
/// provided here.
///
/// Conditional screens can be added to this list, and they will automatically
/// be shown or hidden based on the [Screen.conditionalLibrary] provided.
List<DevToolsScreen> get defaultScreens => <DevToolsScreen>[
      const DevToolsScreen(InspectorScreen(), createController: null),
      DevToolsScreen<TimelineController>(
        const TimelineScreen(),
        createController: () => TimelineController(),
        supportsOffline: true,
      ),
      DevToolsScreen<MemoryController>(
        const MemoryScreen(),
        createController: () => MemoryController(),
      ),
      DevToolsScreen<PerformanceController>(
        const PerformanceScreen(),
        createController: () => PerformanceController(),
        supportsOffline: true,
      ),
      DevToolsScreen<DebuggerController>(
        const DebuggerScreen(),
        createController: () => DebuggerController(),
      ),
      DevToolsScreen<NetworkController>(
        const NetworkScreen(),
        createController: () => NetworkController(),
      ),
      DevToolsScreen<LoggingController>(
        const LoggingScreen(),
        createController: () => LoggingController(),
      ),
      DevToolsScreen<AppSizeController>(
        const AppSizeScreen(),
        createController: () => AppSizeController(),
      ),
// Uncomment to see a sample implementation of a conditional screen.
//      DevToolsScreen<ExampleController>(
//        const ExampleConditionalScreen(),
//        createController: () => ExampleController(),
//        supportsOffline: true,
//      ),
    ];
