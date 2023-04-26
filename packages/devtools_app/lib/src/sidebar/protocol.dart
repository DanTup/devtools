// ignore_for_file: require_trailing_commas, prefer_final_locals, sort_constructors_first, sort_unnamed_constructors_first

import 'dart:convert';

/// Instances of the class [HasToJson] implement [toJson] method that returns
/// a JSON presentation.
abstract class HasToJson {
  /// Returns a JSON presentation of the object.
  Map<String, Object> toJson();
}

/// flutter.getWidgetDescription result
///
/// {
///   "properties": List<FlutterWidgetProperty>
/// }
///
/// Clients may not extend, implement or mix-in this class.
class FlutterGetWidgetDescriptionResult implements HasToJson {
  /// The list of properties of the widget. Some of the properties might be
  /// read only, when their editor is not set. This might be because they have
  /// type that we don't know how to edit, or for compound properties that work
  /// as containers for sub-properties.
  List<FlutterWidgetProperty> properties;

  FlutterGetWidgetDescriptionResult(this.properties);

  factory FlutterGetWidgetDescriptionResult.fromJson(
      JsonDecoder jsonDecoder, String jsonPath, Object? json) {
    json ??= {};
    if (json is Map) {
      List<FlutterWidgetProperty> properties;
      if (json.containsKey('properties')) {
        properties = jsonDecoder.decodeList(
            '$jsonPath.properties',
            json['properties'],
            (String jsonPath, Object? json) =>
                FlutterWidgetProperty.fromJson(jsonDecoder, jsonPath, json));
      } else {
        throw jsonDecoder.mismatch(jsonPath, 'properties');
      }
      return FlutterGetWidgetDescriptionResult(properties);
    } else {
      throw jsonDecoder.mismatch(
          jsonPath, 'flutter.getWidgetDescription result', json);
    }
  }

  @override
  Map<String, Object> toJson() {
    var result = <String, Object>{};
    result['properties'] = properties
        .map((FlutterWidgetProperty value) => value.toJson())
        .toList();
    return result;
  }

  @override
  String toString() => json.encode(toJson());

  @override
  bool operator ==(other) {
    if (other is FlutterGetWidgetDescriptionResult) {
      return listEqual(properties, other.properties,
          (FlutterWidgetProperty a, FlutterWidgetProperty b) => a == b);
    }
    return false;
  }

  @override
  int get hashCode => Object.hashAll(properties);
}

/// Compare the lists [listA] and [listB], using [itemEqual] to compare
/// list elements.
bool listEqual<T>(
    List<T>? listA, List<T>? listB, bool Function(T a, T b) itemEqual) {
  if (listA == null) {
    return listB == null;
  }
  if (listB == null) {
    return false;
  }
  if (listA.length != listB.length) {
    return false;
  }
  for (var i = 0; i < listA.length; i++) {
    if (!itemEqual(listA[i], listB[i])) {
      return false;
    }
  }
  return true;
}

/// Type of callbacks used to decode parts of JSON objects. [jsonPath] is a
/// string describing the part of the JSON object being decoded, and [value] is
/// the part to decode.
typedef JsonDecoderCallback<E extends Object> = E Function(
    String jsonPath, Object? value);

/// JsonDecoder for decoding responses from the server.  This is intended to be
/// used only for testing.  Errors are reported using bare [Exception] objects.
class ResponseDecoder extends JsonDecoder {
  ResponseDecoder();

  @override
  Object mismatch(String jsonPath, String expected, [Object? actual]) {
    var buffer = StringBuffer();
    buffer.write('Expected ');
    buffer.write(expected);
    if (actual != null) {
      buffer.write(' found "');
      buffer.write(json.encode(actual));
      buffer.write('"');
    }
    buffer.write(' at ');
    buffer.write(jsonPath);
    return Exception(buffer.toString());
  }

  @override
  Object missingKey(String jsonPath, String key) {
    return Exception('Missing key $key at $jsonPath');
  }
}

/// Base class for decoding JSON objects. The derived class must implement
/// error reporting logic.
abstract class JsonDecoder {
  /// Decode a JSON object that is expected to be a boolean. The strings "true"
  /// and "false" are also accepted.
  bool decodeBool(String jsonPath, Object? json) {
    if (json is bool) {
      return json;
    } else if (json == 'true') {
      return true;
    } else if (json == 'false') {
      return false;
    }
    throw mismatch(jsonPath, 'bool', json);
  }

  /// Decode a JSON object that is expected to be a double. A string
  /// representation of a double is also accepted.
  double decodeDouble(String jsonPath, Object json) {
    if (json is double) {
      return json;
    } else if (json is int) {
      return json.toDouble();
    } else if (json is String) {
      var value = double.tryParse(json);
      if (value == null) {
        throw mismatch(jsonPath, 'double', json);
      }
      return value;
    }
    throw mismatch(jsonPath, 'double', json);
  }

  /// Decode a JSON object that is expected to be an integer. A string
  /// representation of an integer is also accepted.
  int decodeInt(String jsonPath, Object? json) {
    if (json is int) {
      return json;
    } else if (json is String) {
      var value = int.tryParse(json);
      if (value == null) {
        throw mismatch(jsonPath, 'int', json);
      }
      return value;
    }
    throw mismatch(jsonPath, 'int', json);
  }

  /// Decode a JSON object that is expected to be a List. The [decoder] is used
  /// to decode the items in the list.
  ///
  /// The type parameter [E] is the expected type of the elements in the list.
  List<E> decodeList<E extends Object>(String jsonPath, Object? json,
      [JsonDecoderCallback<E>? decoder]) {
    if (json == null) {
      return <E>[];
    } else if (json is List && decoder != null) {
      var result = <E>[];
      for (var i = 0; i < json.length; i++) {
        result.add(decoder('$jsonPath[$i]', json[i]));
      }
      return result;
    } else {
      throw mismatch(jsonPath, 'List', json);
    }
  }

  /// Decode a JSON object that is expected to be a Map. [keyDecoder] is used
  /// to decode the keys, and [valueDecoder] is used to decode the values.
  Map<K, V> decodeMap<K extends Object, V extends Object>(
      String jsonPath, Object? jsonData,
      {JsonDecoderCallback<K>? keyDecoder,
      JsonDecoderCallback<V>? valueDecoder}) {
    if (jsonData == null) {
      return {};
    } else if (jsonData is Map) {
      var result = <K, V>{};
      jsonData.forEach((key, value) {
        K decodedKey;
        if (keyDecoder != null) {
          decodedKey = keyDecoder('$jsonPath.key', key);
        } else {
          decodedKey = key as K;
        }
        if (valueDecoder != null) {
          value = valueDecoder('$jsonPath[${json.encode(key)}]', value);
        }
        result[decodedKey] = value as V;
      });
      return result;
    } else {
      throw mismatch(jsonPath, 'Map', jsonData);
    }
  }

  /// Decode a JSON object that is expected to be a string.
  String decodeString(String jsonPath, Object? json) {
    if (json is String) {
      return json;
    } else {
      throw mismatch(jsonPath, 'String', json);
    }
  }

  /// Decode a JSON object that is expected to be one of several choices,
  /// where the choices are disambiguated by the contents of the field [field].
  /// [decoders] is a map from each possible string in the field to the decoder
  /// that should be used to decode the JSON object.
  Object decodeUnion(String jsonPath, Object? jsonData, String field,
      Map<String, JsonDecoderCallback> decoders) {
    if (jsonData is Map) {
      if (!jsonData.containsKey(field)) {
        throw missingKey(jsonPath, field);
      }
      var disambiguatorPath = '$jsonPath[${json.encode(field)}]';
      var disambiguator = decodeString(disambiguatorPath, jsonData[field]);
      if (!decoders.containsKey(disambiguator)) {
        throw mismatch(
            disambiguatorPath, 'One of: ${decoders.keys.toList()}', jsonData);
      }
      var decoder = decoders[disambiguator];
      if (decoder == null) {
        throw mismatch(disambiguatorPath, 'Non-null decoder', jsonData);
      }
      return decoder(jsonPath, jsonData);
    } else {
      throw mismatch(jsonPath, 'Map', jsonData);
    }
  }

  /// Create an exception to throw if the JSON object at [jsonPath] fails to
  /// match the API definition of [expected].
  Object mismatch(String jsonPath, String expected, [Object? actual]);

  /// Create an exception to throw if the JSON object at [jsonPath] is missing
  /// the key [key].
  Object missingKey(String jsonPath, String key);
}

/// FlutterWidgetProperty
///
/// {
///   "documentation": optional String
///   "expression": optional String
///   "id": int
///   "isRequired": bool
///   "isSafeToUpdate": bool
///   "name": String
///   "children": optional List<FlutterWidgetProperty>
///   "editor": optional FlutterWidgetPropertyEditor
///   "value": optional FlutterWidgetPropertyValue
/// }
///
/// Clients may not extend, implement or mix-in this class.
class FlutterWidgetProperty implements HasToJson {
  /// The documentation of the property to show to the user. Omitted if the
  /// server does not know the documentation, e.g. because the corresponding
  /// field is not documented.
  String? documentation;

  /// If the value of this property is set, the Dart code of the expression of
  /// this property.
  String? expression;

  /// The unique identifier of the property, must be passed back to the server
  /// when updating the property value. Identifiers become invalid on any
  /// source code change.
  int id;

  /// True if the property is required, e.g. because it corresponds to a
  /// required parameter of a constructor.
  bool isRequired;

  /// If the property expression is a concrete value (e.g. a literal, or an
  /// enum constant), then it is safe to replace the expression with another
  /// concrete value. In this case this field is true. Otherwise, for example
  /// when the expression is a reference to a field, so that its value is
  /// provided from outside, this field is false.
  bool isSafeToUpdate;

  /// The name of the property to display to the user.
  String name;

  /// The list of children properties, if any. For example any property of type
  /// EdgeInsets will have four children properties of type double - left / top
  /// / right / bottom.
  List<FlutterWidgetProperty>? children;

  /// The editor that should be used by the client. This field is omitted if
  /// the server does not know the editor for this property, for example
  /// because it does not have one of the supported types.
  FlutterWidgetPropertyEditor? editor;

  /// If the expression is set, and the server knows the value of the
  /// expression, this field is set.
  FlutterWidgetPropertyValue? value;

  FlutterWidgetProperty(
      this.id, this.isRequired, this.isSafeToUpdate, this.name,
      {this.documentation,
      this.expression,
      this.children,
      this.editor,
      this.value});

  factory FlutterWidgetProperty.fromJson(
      JsonDecoder jsonDecoder, String jsonPath, Object? json) {
    json ??= {};
    if (json is Map) {
      String? documentation;
      if (json.containsKey('documentation')) {
        documentation = jsonDecoder.decodeString(
            '$jsonPath.documentation', json['documentation']);
      }
      String? expression;
      if (json.containsKey('expression')) {
        expression = jsonDecoder.decodeString(
            '$jsonPath.expression', json['expression']);
      }
      int id;
      if (json.containsKey('id')) {
        id = jsonDecoder.decodeInt('$jsonPath.id', json['id']);
      } else {
        throw jsonDecoder.mismatch(jsonPath, 'id');
      }
      bool isRequired;
      if (json.containsKey('isRequired')) {
        isRequired =
            jsonDecoder.decodeBool('$jsonPath.isRequired', json['isRequired']);
      } else {
        throw jsonDecoder.mismatch(jsonPath, 'isRequired');
      }
      bool isSafeToUpdate;
      if (json.containsKey('isSafeToUpdate')) {
        isSafeToUpdate = jsonDecoder.decodeBool(
            '$jsonPath.isSafeToUpdate', json['isSafeToUpdate']);
      } else {
        throw jsonDecoder.mismatch(jsonPath, 'isSafeToUpdate');
      }
      String name;
      if (json.containsKey('name')) {
        name = jsonDecoder.decodeString('$jsonPath.name', json['name']);
      } else {
        throw jsonDecoder.mismatch(jsonPath, 'name');
      }
      List<FlutterWidgetProperty>? children;
      if (json.containsKey('children')) {
        children = jsonDecoder.decodeList(
            '$jsonPath.children',
            json['children'],
            (String jsonPath, Object? json) =>
                FlutterWidgetProperty.fromJson(jsonDecoder, jsonPath, json));
      }
      FlutterWidgetPropertyEditor? editor;
      if (json.containsKey('editor')) {
        editor = FlutterWidgetPropertyEditor.fromJson(
            jsonDecoder, '$jsonPath.editor', json['editor']);
      }
      FlutterWidgetPropertyValue? value;
      if (json.containsKey('value')) {
        value = FlutterWidgetPropertyValue.fromJson(
            jsonDecoder, '$jsonPath.value', json['value']);
      }
      return FlutterWidgetProperty(id, isRequired, isSafeToUpdate, name,
          documentation: documentation,
          expression: expression,
          children: children,
          editor: editor,
          value: value);
    } else {
      throw jsonDecoder.mismatch(jsonPath, 'FlutterWidgetProperty', json);
    }
  }

  @override
  Map<String, Object> toJson() {
    var result = <String, Object>{};
    var documentation = this.documentation;
    if (documentation != null) {
      result['documentation'] = documentation;
    }
    var expression = this.expression;
    if (expression != null) {
      result['expression'] = expression;
    }
    result['id'] = id;
    result['isRequired'] = isRequired;
    result['isSafeToUpdate'] = isSafeToUpdate;
    result['name'] = name;
    var children = this.children;
    if (children != null) {
      result['children'] = children
          .map((FlutterWidgetProperty value) => value.toJson())
          .toList();
    }
    var editor = this.editor;
    if (editor != null) {
      result['editor'] = editor.toJson();
    }
    var value = this.value;
    if (value != null) {
      result['value'] = value.toJson();
    }
    return result;
  }

  @override
  String toString() => json.encode(toJson());

  @override
  bool operator ==(other) {
    if (other is FlutterWidgetProperty) {
      return documentation == other.documentation &&
          expression == other.expression &&
          id == other.id &&
          isRequired == other.isRequired &&
          isSafeToUpdate == other.isSafeToUpdate &&
          name == other.name &&
          listEqual(children, other.children,
              (FlutterWidgetProperty a, FlutterWidgetProperty b) => a == b) &&
          editor == other.editor &&
          value == other.value;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(
        documentation,
        expression,
        id,
        isRequired,
        isSafeToUpdate,
        name,
        Object.hashAll(children ?? []),
        editor,
        value,
      );
}

/// FlutterWidgetPropertyEditor
///
/// {
///   "kind": FlutterWidgetPropertyEditorKind
///   "enumItems": optional List<FlutterWidgetPropertyValueEnumItem>
/// }
///
/// Clients may not extend, implement or mix-in this class.
class FlutterWidgetPropertyEditor implements HasToJson {
  FlutterWidgetPropertyEditorKind kind;

  List<FlutterWidgetPropertyValueEnumItem>? enumItems;

  FlutterWidgetPropertyEditor(this.kind, {this.enumItems});

  factory FlutterWidgetPropertyEditor.fromJson(
      JsonDecoder jsonDecoder, String jsonPath, Object? json) {
    json ??= {};
    if (json is Map) {
      FlutterWidgetPropertyEditorKind kind;
      if (json.containsKey('kind')) {
        kind = FlutterWidgetPropertyEditorKind.fromJson(
            jsonDecoder, '$jsonPath.kind', json['kind']);
      } else {
        throw jsonDecoder.mismatch(jsonPath, 'kind');
      }
      List<FlutterWidgetPropertyValueEnumItem>? enumItems;
      if (json.containsKey('enumItems')) {
        enumItems = jsonDecoder.decodeList(
            '$jsonPath.enumItems',
            json['enumItems'],
            (String jsonPath, Object? json) =>
                FlutterWidgetPropertyValueEnumItem.fromJson(
                    jsonDecoder, jsonPath, json));
      }
      return FlutterWidgetPropertyEditor(kind, enumItems: enumItems);
    } else {
      throw jsonDecoder.mismatch(jsonPath, 'FlutterWidgetPropertyEditor', json);
    }
  }

  @override
  Map<String, Object> toJson() {
    var result = <String, Object>{};
    result['kind'] = kind.toJson();
    var enumItems = this.enumItems;
    if (enumItems != null) {
      result['enumItems'] = enumItems
          .map((FlutterWidgetPropertyValueEnumItem value) => value.toJson())
          .toList();
    }
    return result;
  }

  @override
  String toString() => json.encode(toJson());

  @override
  bool operator ==(other) {
    if (other is FlutterWidgetPropertyEditor) {
      return kind == other.kind &&
          listEqual(
              enumItems,
              other.enumItems,
              (FlutterWidgetPropertyValueEnumItem a,
                      FlutterWidgetPropertyValueEnumItem b) =>
                  a == b);
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        Object.hashAll(enumItems ?? []),
      );
}

/// An interface for enumerated types in the protocol.
///
/// Clients may not extend, implement or mix-in this class.
abstract class Enum {
  /// The name of the enumerated value. This should match the name of the static
  /// getter which provides access to this enumerated value.
  String get name;
}

/// FlutterWidgetPropertyEditorKind
///
/// enum {
///   BOOL
///   DOUBLE
///   ENUM
///   ENUM_LIKE
///   INT
///   STRING
/// }
///
/// Clients may not extend, implement or mix-in this class.
class FlutterWidgetPropertyEditorKind implements Enum {
  /// The editor for a property of type bool.
  static const FlutterWidgetPropertyEditorKind BOOL =
      FlutterWidgetPropertyEditorKind._('BOOL');

  /// The editor for a property of the type double.
  static const FlutterWidgetPropertyEditorKind DOUBLE =
      FlutterWidgetPropertyEditorKind._('DOUBLE');

  /// The editor for choosing an item of an enumeration, see the enumItems
  /// field of FlutterWidgetPropertyEditor.
  static const FlutterWidgetPropertyEditorKind ENUM =
      FlutterWidgetPropertyEditorKind._('ENUM');

  /// The editor for either choosing a pre-defined item from a list of provided
  /// static field references (like ENUM), or specifying a free-form
  /// expression.
  static const FlutterWidgetPropertyEditorKind ENUM_LIKE =
      FlutterWidgetPropertyEditorKind._('ENUM_LIKE');

  /// The editor for a property of type int.
  static const FlutterWidgetPropertyEditorKind INT =
      FlutterWidgetPropertyEditorKind._('INT');

  /// The editor for a property of the type String.
  static const FlutterWidgetPropertyEditorKind STRING =
      FlutterWidgetPropertyEditorKind._('STRING');

  /// A list containing all of the enum values that are defined.
  static const List<FlutterWidgetPropertyEditorKind> VALUES =
      <FlutterWidgetPropertyEditorKind>[
    BOOL,
    DOUBLE,
    ENUM,
    ENUM_LIKE,
    INT,
    STRING
  ];

  @override
  final String name;

  const FlutterWidgetPropertyEditorKind._(this.name);

  factory FlutterWidgetPropertyEditorKind(String name) {
    switch (name) {
      case 'BOOL': return BOOL;
      case 'DOUBLE': return DOUBLE;
      case 'ENUM': return ENUM;
      case 'ENUM_LIKE': return ENUM_LIKE;
      case 'INT': return INT;
      case 'STRING': return STRING;
    }
    throw Exception('Illegal enum value: $name');
  }

  factory FlutterWidgetPropertyEditorKind.fromJson(
      JsonDecoder jsonDecoder, String jsonPath, Object? json) {
    if (json is String) {
      try {
        return FlutterWidgetPropertyEditorKind(json);
      } catch (_) {
        // Fall through
      }
    }
    throw jsonDecoder.mismatch(
        jsonPath, 'FlutterWidgetPropertyEditorKind', json);
  }

  @override
  String toString() => 'FlutterWidgetPropertyEditorKind.$name';

  String toJson() => name;
}

/// FlutterWidgetPropertyValue
///
/// {
///   "boolValue": optional bool
///   "doubleValue": optional double
///   "intValue": optional int
///   "stringValue": optional String
///   "enumValue": optional FlutterWidgetPropertyValueEnumItem
///   "expression": optional String
/// }
///
/// Clients may not extend, implement or mix-in this class.
class FlutterWidgetPropertyValue implements HasToJson {
  bool? boolValue;

  double? doubleValue;

  int? intValue;

  String? stringValue;

  FlutterWidgetPropertyValueEnumItem? enumValue;

  /// A free-form expression, which will be used as the value as is.
  String? expression;

  FlutterWidgetPropertyValue(
      {this.boolValue,
      this.doubleValue,
      this.intValue,
      this.stringValue,
      this.enumValue,
      this.expression});

  factory FlutterWidgetPropertyValue.fromJson(
      JsonDecoder jsonDecoder, String jsonPath, Object? json) {
    json ??= {};
    if (json is Map) {
      bool? boolValue;
      if (json.containsKey('boolValue')) {
        boolValue =
            jsonDecoder.decodeBool('$jsonPath.boolValue', json['boolValue']);
      }
      double? doubleValue;
      if (json.containsKey('doubleValue')) {
        doubleValue = jsonDecoder.decodeDouble(
            '$jsonPath.doubleValue', json['doubleValue'] as Object);
      }
      int? intValue;
      if (json.containsKey('intValue')) {
        intValue =
            jsonDecoder.decodeInt('$jsonPath.intValue', json['intValue']);
      }
      String? stringValue;
      if (json.containsKey('stringValue')) {
        stringValue = jsonDecoder.decodeString(
            '$jsonPath.stringValue', json['stringValue']);
      }
      FlutterWidgetPropertyValueEnumItem? enumValue;
      if (json.containsKey('enumValue')) {
        enumValue = FlutterWidgetPropertyValueEnumItem.fromJson(
            jsonDecoder, '$jsonPath.enumValue', json['enumValue']);
      }
      String? expression;
      if (json.containsKey('expression')) {
        expression = jsonDecoder.decodeString(
            '$jsonPath.expression', json['expression']);
      }
      return FlutterWidgetPropertyValue(
          boolValue: boolValue,
          doubleValue: doubleValue,
          intValue: intValue,
          stringValue: stringValue,
          enumValue: enumValue,
          expression: expression);
    } else {
      throw jsonDecoder.mismatch(jsonPath, 'FlutterWidgetPropertyValue', json);
    }
  }

  @override
  Map<String, Object> toJson() {
    var result = <String, Object>{};
    var boolValue = this.boolValue;
    if (boolValue != null) {
      result['boolValue'] = boolValue;
    }
    var doubleValue = this.doubleValue;
    if (doubleValue != null) {
      result['doubleValue'] = doubleValue;
    }
    var intValue = this.intValue;
    if (intValue != null) {
      result['intValue'] = intValue;
    }
    var stringValue = this.stringValue;
    if (stringValue != null) {
      result['stringValue'] = stringValue;
    }
    var enumValue = this.enumValue;
    if (enumValue != null) {
      result['enumValue'] = enumValue.toJson();
    }
    var expression = this.expression;
    if (expression != null) {
      result['expression'] = expression;
    }
    return result;
  }

  @override
  String toString() => json.encode(toJson());

  @override
  bool operator ==(other) {
    if (other is FlutterWidgetPropertyValue) {
      return boolValue == other.boolValue &&
          doubleValue == other.doubleValue &&
          intValue == other.intValue &&
          stringValue == other.stringValue &&
          enumValue == other.enumValue &&
          expression == other.expression;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(
        boolValue,
        doubleValue,
        intValue,
        stringValue,
        enumValue,
        expression,
      );
}

/// FlutterWidgetPropertyValueEnumItem
///
/// {
///   "libraryUri": String
///   "className": String
///   "name": String
///   "documentation": optional String
/// }
///
/// Clients may not extend, implement or mix-in this class.
class FlutterWidgetPropertyValueEnumItem implements HasToJson {
  /// The URI of the library containing the className. When the enum item is
  /// passed back, this will allow the server to import the corresponding
  /// library if necessary.
  String libraryUri;

  /// The name of the class or enum.
  String className;

  /// The name of the field in the enumeration, or the static field in the
  /// class.
  String name;

  /// The documentation to show to the user. Omitted if the server does not
  /// know the documentation, e.g. because the corresponding field is not
  /// documented.
  String? documentation;

  FlutterWidgetPropertyValueEnumItem(this.libraryUri, this.className, this.name,
      {this.documentation});

  factory FlutterWidgetPropertyValueEnumItem.fromJson(
      JsonDecoder jsonDecoder, String jsonPath, Object? json) {
    json ??= {};
    if (json is Map) {
      String libraryUri;
      if (json.containsKey('libraryUri')) {
        libraryUri = jsonDecoder.decodeString(
            '$jsonPath.libraryUri', json['libraryUri']);
      } else {
        throw jsonDecoder.mismatch(jsonPath, 'libraryUri');
      }
      String className;
      if (json.containsKey('className')) {
        className =
            jsonDecoder.decodeString('$jsonPath.className', json['className']);
      } else {
        throw jsonDecoder.mismatch(jsonPath, 'className');
      }
      String name;
      if (json.containsKey('name')) {
        name = jsonDecoder.decodeString('$jsonPath.name', json['name']);
      } else {
        throw jsonDecoder.mismatch(jsonPath, 'name');
      }
      String? documentation;
      if (json.containsKey('documentation')) {
        documentation = jsonDecoder.decodeString(
            '$jsonPath.documentation', json['documentation']);
      }
      return FlutterWidgetPropertyValueEnumItem(libraryUri, className, name,
          documentation: documentation);
    } else {
      throw jsonDecoder.mismatch(
          jsonPath, 'FlutterWidgetPropertyValueEnumItem', json);
    }
  }

  @override
  Map<String, Object> toJson() {
    var result = <String, Object>{};
    result['libraryUri'] = libraryUri;
    result['className'] = className;
    result['name'] = name;
    var documentation = this.documentation;
    if (documentation != null) {
      result['documentation'] = documentation;
    }
    return result;
  }

  @override
  String toString() => json.encode(toJson());

  @override
  bool operator ==(other) {
    if (other is FlutterWidgetPropertyValueEnumItem) {
      return libraryUri == other.libraryUri &&
          className == other.className &&
          name == other.name &&
          documentation == other.documentation;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(
        libraryUri,
        className,
        name,
        documentation,
      );
}
