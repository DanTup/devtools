// ignore_for_file: prefer_single_quotes

import 'dart:async';

import 'package:flutter/material.dart';

import 'src/shared/config_specific/post_message/post_message.dart';
import 'src/sidebar/protocol.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      //
      theme: ThemeData(primarySwatch: Colors.green),
      home: const MyHomePage(title: 'Widget Property Editor'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  StreamSubscription? _postMessageSubscription;
  String? _parentOrigin;

  @override
  void initState() {
    super.initState();

    try {
      _postMessageSubscription = onPostMessage.listen((event) {
        // _appendMessage('${event.data}');
        _handlePostMessage(event);
      });
    } on UnsupportedError {
      // for non-web testing
    }
  }

  final jsonDecoder = ResponseDecoder();

  FlutterGetWidgetDescriptionResult? _widgetDescription;
  String? _widgetInstanceCreationUri;
  int? _widgetInstanceCreationOffset;

  void _handlePostMessage(PostMessageEvent event) {
    _parentOrigin = event.origin;
    final data = event.data;
    if (data is Map) {
      _handleMessage(data);
    }
  }

  void _handleMessage(Map data) {
    final method = data['method'];
    final rawParams = data['params'];
    final params = rawParams is Map ? rawParams : null;
    switch (method) {
      case 'setWidget':
        setState(() {
          if (params != null) {
            _widgetInstanceCreationUri = params['uri'] as String;
            _widgetInstanceCreationOffset = params['offset'] as int;
            _widgetDescription = FlutterGetWidgetDescriptionResult.fromJson(
              jsonDecoder,
              'result',
              params['description'],
            );
          } else {
            _widgetInstanceCreationUri = null;
            _widgetInstanceCreationOffset = null;
            _widgetDescription = null;
          }
        });
    }
  }

  @override
  void dispose() {
    super.dispose();
    print('Unsubscribing from postMessage!');
    unawaited(_postMessageSubscription?.cancel()); // Is this valid?
    _postMessageSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(50),
          child: Column(
            children: [
              if (_widgetInstanceCreationUri != null &&
                  _widgetInstanceCreationOffset != null)
                Text(
                  '$_widgetInstanceCreationUri: $_widgetInstanceCreationOffset',
                ),
              if (_widgetDescription != null)
                Table(
                  children: [
                    for (final property in _widgetDescription!.properties
                        .where((p) => p.editor != null))
                      _buildRow(property),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Text('Test'),
        onPressed: () {
          setState(() {
            _handleMessage(_testWidgetData);
          });
        },
      ),
    );
  }

  TableRow _buildRow(FlutterWidgetProperty property) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: _tooltipIf(
            message: property.documentation,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Text(property.name),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: PropertyEditor(
              property,
              onValueChanged: (value) => _handleValueChange(property, value),
              key: ValueKey(property.id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tooltipIf({required Widget child, required String? message}) {
    return message == null ? child : Tooltip(message: message, child: child);
  }

  void _handleValueChange(
    FlutterWidgetProperty property,
    FlutterWidgetPropertyValue value,
  ) {
    if (_parentOrigin == null) return;
    postMessage(
      {
        'method': 'setWidgetPropertyValue',
        'params': {
          'id': property.id,
          'value': value.toJson(),
        }
      },
      _parentOrigin!,
    );
  }
}

class PropertyEditor extends StatelessWidget {
  const PropertyEditor(this.property, {this.onValueChanged, super.key});

  final FlutterWidgetProperty property;
  final Function(FlutterWidgetPropertyValue value)? onValueChanged;

  @override
  Widget build(BuildContext context) {
    return property.editor?.kind == FlutterWidgetPropertyEditorKind.DOUBLE
        ? DoubleEditor(
            property,
            onValueChanged: onValueChanged,
          )
        : property.editor?.kind == FlutterWidgetPropertyEditorKind.ENUM_LIKE ||
                property.editor?.kind == FlutterWidgetPropertyEditorKind.ENUM
            ? EnumLikeEditor(
                property,
                onValueChanged: onValueChanged,
              )
            : Text(
                (property.value?.boolValue ??
                        property.value?.doubleValue ??
                        property.value?.enumValue ??
                        property.value?.expression ??
                        property.value?.intValue ??
                        property.value?.stringValue ??
                        property.expression)
                    .toString(),
              );
  }
}

class DoubleEditor extends StatefulWidget {
  const DoubleEditor(this.property, {this.onValueChanged, super.key});

  final FlutterWidgetProperty property;

  final Function(FlutterWidgetPropertyValue value)? onValueChanged;

  @override
  State<DoubleEditor> createState() => _DoubleEditorState();
}

class _DoubleEditorState extends State<DoubleEditor> {
  final textController = TextEditingController();
  double? _currentValue;

  @override
  void initState() {
    super.initState();

    _currentValue = widget.property.value?.doubleValue ??
        widget.property.value?.intValue?.toDouble();
    textController.text = _currentValue?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: textController,
          onSubmitted: _handleTextChange,
        ),
        Slider(
          max: 500,
          divisions: 500,
          value: _currentValue ?? 0,
          onChanged: _handleSliderChange,
          onChangeEnd: _handleSliderChangeEnd,
        )
      ],
    );
  }

  void _handleTextChange(String value) {
    final doubleValue = double.tryParse(value);
    if (doubleValue == null && value.isNotEmpty) {
      // Invalid input, ignore.
      return;
    }
    _setValue(doubleValue, send: true);
  }

  void _handleSliderChange(double value) {
    _setValue(value, send: false);
  }

  void _handleSliderChangeEnd(double value) {
    _setValue(value, send: true);
  }

  void _setValue(double? value, {required bool send}) {
    setState(() {
      _currentValue = value;
      textController.text = _currentValue?.toString() ?? '';
    });
    if (send) {
      widget.onValueChanged
          ?.call(FlutterWidgetPropertyValue(doubleValue: _currentValue));
    }
  }
}

class EnumLikeEditor extends StatefulWidget {
  const EnumLikeEditor(this.property, {this.onValueChanged, super.key});

  final FlutterWidgetProperty property;

  final Function(FlutterWidgetPropertyValue value)? onValueChanged;

  @override
  State<EnumLikeEditor> createState() => _EnumLikeEditorState();
}

class _EnumLikeEditorState extends State<EnumLikeEditor> {
  FlutterWidgetPropertyValueEnumItem? _currentValue;

  @override
  void initState() {
    super.initState();

    _currentValue = widget.property.value?.enumValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButton(
          items: [
            const DropdownMenuItem<FlutterWidgetPropertyValueEnumItem?>(
              child: Text(''),
            ),
            ...?widget.property.editor?.enumItems?.map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item.name),
              ),
            ),
          ],
          value: _currentValue,
          onChanged: _handleItemChange,
        ),
      ],
    );
  }

  void _setValue(
    FlutterWidgetPropertyValueEnumItem? value, {
    required bool send,
  }) {
    setState(() {
      _currentValue = value;
    });
    if (send) {
      widget.onValueChanged
          ?.call(FlutterWidgetPropertyValue(enumValue: _currentValue));
    }
  }

  void _handleItemChange(value) {
    _setValue(value, send: true);
  }
}

const _testWidgetData = {
  "method": "setWidget",
  "params": {
    "description": {
      "properties": [
        {
          "documentation":
              "The decoration to paint behind the [child].\n\nUse the [color] property to specify a simple solid color.\n\nThe [child] is not clipped to the decoration. To clip a child to the shape\nof a particular [ShapeDecoration], consider using a [ClipPath] widget.",
          "expression": "const BoxDecoration(color: Colors.red)",
          "id": 111,
          "isRequired": false,
          "isSafeToUpdate": false,
          "name": "decoration",
          "children": []
        },
        {
          "documentation":
              "Empty space to inscribe inside the [decoration]. The [child], if any, is\nplaced inside this padding.\n\nThis padding is in addition to any padding inherent in the [decoration];\nsee [Decoration.padding].",
          "expression": "const EdgeInsets.all(58)",
          "id": 112,
          "isRequired": false,
          "isSafeToUpdate": false,
          "name": "padding",
          "children": [
            {
              "documentation": "The offset from the left.",
              "expression": "58",
              "id": 113,
              "isRequired": true,
              "isSafeToUpdate": true,
              "name": "left",
              "children": [],
              "editor": {"kind": "DOUBLE"},
              "value": {"doubleValue": 58}
            },
            {
              "documentation": "The offset from the top.",
              "expression": "58",
              "id": 114,
              "isRequired": true,
              "isSafeToUpdate": true,
              "name": "top",
              "children": [],
              "editor": {"kind": "DOUBLE"},
              "value": {"doubleValue": 58}
            },
            {
              "documentation": "The offset from the right.",
              "expression": "58",
              "id": 115,
              "isRequired": true,
              "isSafeToUpdate": true,
              "name": "right",
              "children": [],
              "editor": {"kind": "DOUBLE"},
              "value": {"doubleValue": 58}
            },
            {
              "documentation": "The offset from the bottom.",
              "expression": "58",
              "id": 116,
              "isRequired": true,
              "isSafeToUpdate": true,
              "name": "bottom",
              "children": [],
              "editor": {"kind": "DOUBLE"},
              "value": {"doubleValue": 58}
            }
          ]
        },
        {
          "documentation":
              "The [child] contained by the container.\n\nIf null, and if the [constraints] are unbounded or also null, the\ncontainer will expand to fill all available space in its parent, unless\nthe parent provides unbounded constraints, in which case the container\nwill attempt to be as small as possible.\n\n{@macro flutter.widgets.ProxyWidget.child}",
          "expression":
              "Container(\n            decoration: const BoxDecoration(color: Colors.white),\n            child: Column(\n              mainAxisAlignment: MainAxisAlignment.center,\n              children: <Widget>[\n                const Text(\n                  'You have pushed the button this many times:',\n                ),\n                Text(\n                  '\$_counter',\n                  style: Theme.of(context).textTheme.headlineMedium,\n                ),\n              ],\n            ),\n          )",
          "id": 117,
          "isRequired": false,
          "isSafeToUpdate": false,
          "name": "child",
          "children": []
        },
        {
          "id": 118,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "key",
          "children": []
        },
        {
          "documentation":
              "Align the [child] within the container.\n\nIf non-null, the container will expand to fill its parent and position its\nchild within itself according to the given value. If the incoming\nconstraints are unbounded, then the child will be shrink-wrapped instead.\n\nIgnored if [child] is null.\n\nSee also:\n\n * [Alignment], a class with convenient constants typically used to\n   specify an [AlignmentGeometry].\n * [AlignmentDirectional], like [Alignment] for specifying alignments\n   relative to text direction.",
          "id": 119,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "alignment",
          "children": [],
          "editor": {
            "kind": "ENUM_LIKE",
            "enumItems": [
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "topLeft",
                "documentation": "The top left corner."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "topCenter",
                "documentation": "The center point along the top edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "topRight",
                "documentation": "The top right corner."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "centerLeft",
                "documentation": "The center point along the left edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "center",
                "documentation":
                    "The center point, both horizontally and vertically."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "centerRight",
                "documentation": "The center point along the right edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "bottomLeft",
                "documentation": "The bottom left corner."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "bottomCenter",
                "documentation": "The center point along the bottom edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "bottomRight",
                "documentation": "The bottom right corner."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "topStart",
                "documentation": "The top corner on the \"start\" side."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "topCenter",
                "documentation":
                    "The center point along the top edge.\n\nConsider using [Alignment.topCenter] instead, as it does not need\nto be [resolve]d to be used."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "topEnd",
                "documentation": "The top corner on the \"end\" side."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "centerStart",
                "documentation": "The center point along the \"start\" edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "center",
                "documentation":
                    "The center point, both horizontally and vertically.\n\nConsider using [Alignment.center] instead, as it does not need to\nbe [resolve]d to be used."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "centerEnd",
                "documentation": "The center point along the \"end\" edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "bottomStart",
                "documentation": "The bottom corner on the \"start\" side."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "bottomCenter",
                "documentation":
                    "The center point along the bottom edge.\n\nConsider using [Alignment.bottomCenter] instead, as it does not\nneed to be [resolve]d to be used."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "bottomEnd",
                "documentation": "The bottom corner on the \"end\" side."
              }
            ]
          }
        },
        {
          "documentation":
              "The color to paint behind the [child].\n\nThis property should be preferred when the background is a simple color.\nFor other cases, such as gradients or images, use the [decoration]\nproperty.\n\nIf the [decoration] is used, this property must be null. A background\ncolor may still be painted by the [decoration] even if this property is\nnull.",
          "id": 120,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "color",
          "children": []
        },
        {
          "documentation": "The decoration to paint in front of the [child].",
          "id": 121,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "foregroundDecoration",
          "children": []
        },
        {
          "id": 122,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "width",
          "children": [],
          "editor": {"kind": "DOUBLE"}
        },
        {
          "id": 123,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "height",
          "children": [],
          "editor": {"kind": "DOUBLE"}
        },
        {
          "id": 124,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "constraints",
          "children": []
        },
        {
          "documentation":
              "Empty space to surround the [decoration] and [child].",
          "id": 125,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "margin",
          "children": [
            {
              "documentation": "The offset from the left.",
              "id": 126,
              "isRequired": true,
              "isSafeToUpdate": true,
              "name": "left",
              "children": [],
              "editor": {"kind": "DOUBLE"}
            },
            {
              "documentation": "The offset from the top.",
              "id": 127,
              "isRequired": true,
              "isSafeToUpdate": true,
              "name": "top",
              "children": [],
              "editor": {"kind": "DOUBLE"}
            },
            {
              "documentation": "The offset from the right.",
              "id": 128,
              "isRequired": true,
              "isSafeToUpdate": true,
              "name": "right",
              "children": [],
              "editor": {"kind": "DOUBLE"}
            },
            {
              "documentation": "The offset from the bottom.",
              "id": 129,
              "isRequired": true,
              "isSafeToUpdate": true,
              "name": "bottom",
              "children": [],
              "editor": {"kind": "DOUBLE"}
            }
          ]
        },
        {
          "documentation":
              "The transformation matrix to apply before painting the container.",
          "id": 130,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "transform",
          "children": []
        },
        {
          "documentation":
              "The alignment of the origin, relative to the size of the container, if [transform] is specified.\n\nWhen [transform] is null, the value of this property is ignored.\n\nSee also:\n\n * [Transform.alignment], which is set by this property.",
          "id": 131,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "transformAlignment",
          "children": [],
          "editor": {
            "kind": "ENUM_LIKE",
            "enumItems": [
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "topLeft",
                "documentation": "The top left corner."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "topCenter",
                "documentation": "The center point along the top edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "topRight",
                "documentation": "The top right corner."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "centerLeft",
                "documentation": "The center point along the left edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "center",
                "documentation":
                    "The center point, both horizontally and vertically."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "centerRight",
                "documentation": "The center point along the right edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "bottomLeft",
                "documentation": "The bottom left corner."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "bottomCenter",
                "documentation": "The center point along the bottom edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "Alignment",
                "name": "bottomRight",
                "documentation": "The bottom right corner."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "topStart",
                "documentation": "The top corner on the \"start\" side."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "topCenter",
                "documentation":
                    "The center point along the top edge.\n\nConsider using [Alignment.topCenter] instead, as it does not need\nto be [resolve]d to be used."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "topEnd",
                "documentation": "The top corner on the \"end\" side."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "centerStart",
                "documentation": "The center point along the \"start\" edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "center",
                "documentation":
                    "The center point, both horizontally and vertically.\n\nConsider using [Alignment.center] instead, as it does not need to\nbe [resolve]d to be used."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "centerEnd",
                "documentation": "The center point along the \"end\" edge."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "bottomStart",
                "documentation": "The bottom corner on the \"start\" side."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "bottomCenter",
                "documentation":
                    "The center point along the bottom edge.\n\nConsider using [Alignment.bottomCenter] instead, as it does not\nneed to be [resolve]d to be used."
              },
              {
                "libraryUri": "package:flutter/src/painting/alignment.dart",
                "className": "AlignmentDirectional",
                "name": "bottomEnd",
                "documentation": "The bottom corner on the \"end\" side."
              }
            ]
          }
        },
        {
          "documentation":
              "The clip behavior when [Container.decoration] is not null.\n\nDefaults to [Clip.none]. Must be [Clip.none] if [decoration] is null.\n\nIf a clip is to be applied, the [Decoration.getClipPath] method\nfor the provided decoration must return a clip path. (This is not\nsupported by all decorations; the default implementation of that\nmethod throws an [UnsupportedError].)",
          "id": 132,
          "isRequired": false,
          "isSafeToUpdate": true,
          "name": "clipBehavior",
          "children": [],
          "editor": {
            "kind": "ENUM",
            "enumItems": [
              {
                "libraryUri": "dart:ui",
                "className": "Clip",
                "name": "none",
                "documentation":
                    "No clip at all.\n\nThis is the default option for most widgets: if the content does not\noverflow the widget boundary, don't pay any performance cost for clipping.\n\nIf the content does overflow, please explicitly specify the following\n[Clip] options:\n * [hardEdge], which is the fastest clipping, but with lower fidelity.\n * [antiAlias], which is a little slower than [hardEdge], but with smoothed edges.\n * [antiAliasWithSaveLayer], which is much slower than [antiAlias], and should\n   rarely be used."
              },
              {
                "libraryUri": "dart:ui",
                "className": "Clip",
                "name": "hardEdge",
                "documentation":
                    "Clip, but do not apply anti-aliasing.\n\nThis mode enables clipping, but curves and non-axis-aligned straight lines will be\njagged as no effort is made to anti-alias.\n\nFaster than other clipping modes, but slower than [none].\n\nThis is a reasonable choice when clipping is needed, if the container is an axis-\naligned rectangle or an axis-aligned rounded rectangle with very small corner radii.\n\nSee also:\n\n * [antiAlias], which is more reasonable when clipping is needed and the shape is not\n   an axis-aligned rectangle."
              },
              {
                "libraryUri": "dart:ui",
                "className": "Clip",
                "name": "antiAlias",
                "documentation":
                    "Clip with anti-aliasing.\n\nThis mode has anti-aliased clipping edges to achieve a smoother look.\n\nIt' s much faster than [antiAliasWithSaveLayer], but slower than [hardEdge].\n\nThis will be the common case when dealing with circles and arcs.\n\nDifferent from [hardEdge] and [antiAliasWithSaveLayer], this clipping may have\nbleeding edge artifacts.\n(See https://fiddle.skia.org/c/21cb4c2b2515996b537f36e7819288ae for an example.)\n\nSee also:\n\n * [hardEdge], which is a little faster, but with lower fidelity.\n * [antiAliasWithSaveLayer], which is much slower, but can avoid the\n   bleeding edges if there's no other way.\n * [Paint.isAntiAlias], which is the anti-aliasing switch for general draw operations."
              },
              {
                "libraryUri": "dart:ui",
                "className": "Clip",
                "name": "antiAliasWithSaveLayer",
                "documentation":
                    "Clip with anti-aliasing and saveLayer immediately following the clip.\n\nThis mode not only clips with anti-aliasing, but also allocates an offscreen\nbuffer. All subsequent paints are carried out on that buffer before finally\nbeing clipped and composited back.\n\nThis is very slow. It has no bleeding edge artifacts (that [antiAlias] has)\nbut it changes the semantics as an offscreen buffer is now introduced.\n(See https://github.com/flutter/flutter/issues/18057#issuecomment-394197336\nfor a difference between paint without saveLayer and paint with saveLayer.)\n\nThis will be only rarely needed. One case where you might need this is if\nyou have an image overlaid on a very different background color. In these\ncases, consider whether you can avoid overlaying multiple colors in one\nspot (e.g. by having the background color only present where the image is\nabsent). If you can, [antiAlias] would be fine and much faster.\n\nSee also:\n\n * [antiAlias], which is much faster, and has similar clipping results."
              }
            ]
          }
        },
        {
          "id": 133,
          "isRequired": true,
          "isSafeToUpdate": false,
          "name": "Container",
          "children": [
            {
              "id": 134,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "key",
              "children": []
            },
            {
              "documentation":
                  "Align the [child] within the container.\n\nIf non-null, the container will expand to fill its parent and position its\nchild within itself according to the given value. If the incoming\nconstraints are unbounded, then the child will be shrink-wrapped instead.\n\nIgnored if [child] is null.\n\nSee also:\n\n * [Alignment], a class with convenient constants typically used to\n   specify an [AlignmentGeometry].\n * [AlignmentDirectional], like [Alignment] for specifying alignments\n   relative to text direction.",
              "id": 135,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "alignment",
              "children": [],
              "editor": {
                "kind": "ENUM_LIKE",
                "enumItems": [
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "topLeft",
                    "documentation": "The top left corner."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "topCenter",
                    "documentation": "The center point along the top edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "topRight",
                    "documentation": "The top right corner."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "centerLeft",
                    "documentation": "The center point along the left edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "center",
                    "documentation":
                        "The center point, both horizontally and vertically."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "centerRight",
                    "documentation": "The center point along the right edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "bottomLeft",
                    "documentation": "The bottom left corner."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "bottomCenter",
                    "documentation": "The center point along the bottom edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "bottomRight",
                    "documentation": "The bottom right corner."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "topStart",
                    "documentation": "The top corner on the \"start\" side."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "topCenter",
                    "documentation":
                        "The center point along the top edge.\n\nConsider using [Alignment.topCenter] instead, as it does not need\nto be [resolve]d to be used."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "topEnd",
                    "documentation": "The top corner on the \"end\" side."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "centerStart",
                    "documentation":
                        "The center point along the \"start\" edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "center",
                    "documentation":
                        "The center point, both horizontally and vertically.\n\nConsider using [Alignment.center] instead, as it does not need to\nbe [resolve]d to be used."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "centerEnd",
                    "documentation": "The center point along the \"end\" edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "bottomStart",
                    "documentation": "The bottom corner on the \"start\" side."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "bottomCenter",
                    "documentation":
                        "The center point along the bottom edge.\n\nConsider using [Alignment.bottomCenter] instead, as it does not\nneed to be [resolve]d to be used."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "bottomEnd",
                    "documentation": "The bottom corner on the \"end\" side."
                  }
                ]
              }
            },
            {
              "documentation":
                  "Empty space to inscribe inside the [decoration]. The [child], if any, is\nplaced inside this padding.\n\nThis padding is in addition to any padding inherent in the [decoration];\nsee [Decoration.padding].",
              "id": 136,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "padding",
              "children": [
                {
                  "documentation": "The offset from the left.",
                  "id": 137,
                  "isRequired": true,
                  "isSafeToUpdate": true,
                  "name": "left",
                  "children": [],
                  "editor": {"kind": "DOUBLE"}
                },
                {
                  "documentation": "The offset from the top.",
                  "id": 138,
                  "isRequired": true,
                  "isSafeToUpdate": true,
                  "name": "top",
                  "children": [],
                  "editor": {"kind": "DOUBLE"}
                },
                {
                  "documentation": "The offset from the right.",
                  "id": 139,
                  "isRequired": true,
                  "isSafeToUpdate": true,
                  "name": "right",
                  "children": [],
                  "editor": {"kind": "DOUBLE"}
                },
                {
                  "documentation": "The offset from the bottom.",
                  "id": 140,
                  "isRequired": true,
                  "isSafeToUpdate": true,
                  "name": "bottom",
                  "children": [],
                  "editor": {"kind": "DOUBLE"}
                }
              ]
            },
            {
              "documentation":
                  "The color to paint behind the [child].\n\nThis property should be preferred when the background is a simple color.\nFor other cases, such as gradients or images, use the [decoration]\nproperty.\n\nIf the [decoration] is used, this property must be null. A background\ncolor may still be painted by the [decoration] even if this property is\nnull.",
              "id": 141,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "color",
              "children": []
            },
            {
              "documentation":
                  "The decoration to paint behind the [child].\n\nUse the [color] property to specify a simple solid color.\n\nThe [child] is not clipped to the decoration. To clip a child to the shape\nof a particular [ShapeDecoration], consider using a [ClipPath] widget.",
              "id": 142,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "decoration",
              "children": []
            },
            {
              "documentation":
                  "The decoration to paint in front of the [child].",
              "id": 143,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "foregroundDecoration",
              "children": []
            },
            {
              "id": 144,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "width",
              "children": [],
              "editor": {"kind": "DOUBLE"}
            },
            {
              "id": 145,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "height",
              "children": [],
              "editor": {"kind": "DOUBLE"}
            },
            {
              "id": 146,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "constraints",
              "children": []
            },
            {
              "documentation":
                  "Empty space to surround the [decoration] and [child].",
              "id": 147,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "margin",
              "children": [
                {
                  "documentation": "The offset from the left.",
                  "id": 148,
                  "isRequired": true,
                  "isSafeToUpdate": true,
                  "name": "left",
                  "children": [],
                  "editor": {"kind": "DOUBLE"}
                },
                {
                  "documentation": "The offset from the top.",
                  "id": 149,
                  "isRequired": true,
                  "isSafeToUpdate": true,
                  "name": "top",
                  "children": [],
                  "editor": {"kind": "DOUBLE"}
                },
                {
                  "documentation": "The offset from the right.",
                  "id": 150,
                  "isRequired": true,
                  "isSafeToUpdate": true,
                  "name": "right",
                  "children": [],
                  "editor": {"kind": "DOUBLE"}
                },
                {
                  "documentation": "The offset from the bottom.",
                  "id": 151,
                  "isRequired": true,
                  "isSafeToUpdate": true,
                  "name": "bottom",
                  "children": [],
                  "editor": {"kind": "DOUBLE"}
                }
              ]
            },
            {
              "documentation":
                  "The transformation matrix to apply before painting the container.",
              "id": 152,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "transform",
              "children": []
            },
            {
              "documentation":
                  "The alignment of the origin, relative to the size of the container, if [transform] is specified.\n\nWhen [transform] is null, the value of this property is ignored.\n\nSee also:\n\n * [Transform.alignment], which is set by this property.",
              "id": 153,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "transformAlignment",
              "children": [],
              "editor": {
                "kind": "ENUM_LIKE",
                "enumItems": [
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "topLeft",
                    "documentation": "The top left corner."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "topCenter",
                    "documentation": "The center point along the top edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "topRight",
                    "documentation": "The top right corner."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "centerLeft",
                    "documentation": "The center point along the left edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "center",
                    "documentation":
                        "The center point, both horizontally and vertically."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "centerRight",
                    "documentation": "The center point along the right edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "bottomLeft",
                    "documentation": "The bottom left corner."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "bottomCenter",
                    "documentation": "The center point along the bottom edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "Alignment",
                    "name": "bottomRight",
                    "documentation": "The bottom right corner."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "topStart",
                    "documentation": "The top corner on the \"start\" side."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "topCenter",
                    "documentation":
                        "The center point along the top edge.\n\nConsider using [Alignment.topCenter] instead, as it does not need\nto be [resolve]d to be used."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "topEnd",
                    "documentation": "The top corner on the \"end\" side."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "centerStart",
                    "documentation":
                        "The center point along the \"start\" edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "center",
                    "documentation":
                        "The center point, both horizontally and vertically.\n\nConsider using [Alignment.center] instead, as it does not need to\nbe [resolve]d to be used."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "centerEnd",
                    "documentation": "The center point along the \"end\" edge."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "bottomStart",
                    "documentation": "The bottom corner on the \"start\" side."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "bottomCenter",
                    "documentation":
                        "The center point along the bottom edge.\n\nConsider using [Alignment.bottomCenter] instead, as it does not\nneed to be [resolve]d to be used."
                  },
                  {
                    "libraryUri": "package:flutter/src/painting/alignment.dart",
                    "className": "AlignmentDirectional",
                    "name": "bottomEnd",
                    "documentation": "The bottom corner on the \"end\" side."
                  }
                ]
              }
            },
            {
              "documentation":
                  "The clip behavior when [Container.decoration] is not null.\n\nDefaults to [Clip.none]. Must be [Clip.none] if [decoration] is null.\n\nIf a clip is to be applied, the [Decoration.getClipPath] method\nfor the provided decoration must return a clip path. (This is not\nsupported by all decorations; the default implementation of that\nmethod throws an [UnsupportedError].)",
              "id": 155,
              "isRequired": false,
              "isSafeToUpdate": true,
              "name": "clipBehavior",
              "children": [],
              "editor": {
                "kind": "ENUM",
                "enumItems": [
                  {
                    "libraryUri": "dart:ui",
                    "className": "Clip",
                    "name": "none",
                    "documentation":
                        "No clip at all.\n\nThis is the default option for most widgets: if the content does not\noverflow the widget boundary, don't pay any performance cost for clipping.\n\nIf the content does overflow, please explicitly specify the following\n[Clip] options:\n * [hardEdge], which is the fastest clipping, but with lower fidelity.\n * [antiAlias], which is a little slower than [hardEdge], but with smoothed edges.\n * [antiAliasWithSaveLayer], which is much slower than [antiAlias], and should\n   rarely be used."
                  },
                  {
                    "libraryUri": "dart:ui",
                    "className": "Clip",
                    "name": "hardEdge",
                    "documentation":
                        "Clip, but do not apply anti-aliasing.\n\nThis mode enables clipping, but curves and non-axis-aligned straight lines will be\njagged as no effort is made to anti-alias.\n\nFaster than other clipping modes, but slower than [none].\n\nThis is a reasonable choice when clipping is needed, if the container is an axis-\naligned rectangle or an axis-aligned rounded rectangle with very small corner radii.\n\nSee also:\n\n * [antiAlias], which is more reasonable when clipping is needed and the shape is not\n   an axis-aligned rectangle."
                  },
                  {
                    "libraryUri": "dart:ui",
                    "className": "Clip",
                    "name": "antiAlias",
                    "documentation":
                        "Clip with anti-aliasing.\n\nThis mode has anti-aliased clipping edges to achieve a smoother look.\n\nIt' s much faster than [antiAliasWithSaveLayer], but slower than [hardEdge].\n\nThis will be the common case when dealing with circles and arcs.\n\nDifferent from [hardEdge] and [antiAliasWithSaveLayer], this clipping may have\nbleeding edge artifacts.\n(See https://fiddle.skia.org/c/21cb4c2b2515996b537f36e7819288ae for an example.)\n\nSee also:\n\n * [hardEdge], which is a little faster, but with lower fidelity.\n * [antiAliasWithSaveLayer], which is much slower, but can avoid the\n   bleeding edges if there's no other way.\n * [Paint.isAntiAlias], which is the anti-aliasing switch for general draw operations."
                  },
                  {
                    "libraryUri": "dart:ui",
                    "className": "Clip",
                    "name": "antiAliasWithSaveLayer",
                    "documentation":
                        "Clip with anti-aliasing and saveLayer immediately following the clip.\n\nThis mode not only clips with anti-aliasing, but also allocates an offscreen\nbuffer. All subsequent paints are carried out on that buffer before finally\nbeing clipped and composited back.\n\nThis is very slow. It has no bleeding edge artifacts (that [antiAlias] has)\nbut it changes the semantics as an offscreen buffer is now introduced.\n(See https://github.com/flutter/flutter/issues/18057#issuecomment-394197336\nfor a difference between paint without saveLayer and paint with saveLayer.)\n\nThis will be only rarely needed. One case where you might need this is if\nyou have an image overlaid on a very different background color. In these\ncases, consider whether you can avoid overlaying multiple colors in one\nspot (e.g. by having the background color only present where the image is\nabsent). If you can, [antiAlias] would be fine and much faster.\n\nSee also:\n\n * [antiAlias], which is much faster, and has similar clipping results."
                  }
                ]
              }
            }
          ]
        }
      ]
    },
    "offset": 1007,
    "uri":
        "file:///Users/danny/Desktop/dart_samples/flutter_counter/lib/main.dart"
  }
};
