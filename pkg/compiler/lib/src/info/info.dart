// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Data collected by the dump-info task.
library compiler.src.lib.info;

// Note: this file intentionally doesn't import anything from the compiler. That
// should make it easier for tools to depend on this library. The idea is that
// by using this library, tools can consume the information in the same way it
// is produced by the compiler.
// TODO(sigmund): make this a proper public API (export this explicitly at the
// lib folder level.)

/// Common interface to many pieces of information generated by the compiler.
abstract class Info {
  /// An identifier for the kind of information.
  InfoKind get kind;

  /// Name of the element associated with this info.
  String name;

  /// An id to uniquely identify this info among infos of the same [kind].
  int get id;

  /// A globally unique id combining [kind] and [id] together.
  String get serializedId;

  /// Bytes used in the generated code for the corresponding element.
  int size;

  /// Info of the enclosing element.
  Info parent;

  /// Serializes the information into a JSON format.
  // TODO(sigmund): refactor and put toJson outside the class, so we can have 2
  // different serializer/deserializers at once.
  Map toJson();

  void accept(InfoVisitor visitor);
}

/// Common information used for most kind of elements.
// TODO(sigmund): add more:
//  - inputSize: bytes used in the Dart source program
abstract class BasicInfo implements Info {
  final InfoKind kind;
  final int id;
  int size;
  Info parent;

  String get serializedId => '${_kindToString(kind)}/$id';

  String name;

  /// If using deferred libraries, where the element associated with this info
  /// is generated.
  OutputUnitInfo outputUnit;

  BasicInfo(this.kind, this.id, this.name, this.outputUnit, this.size);

  BasicInfo._fromId(String serializedId)
     : kind = _kindFromSerializedId(serializedId),
       id = _idFromSerializedId(serializedId);

  Map toJson() {
    var res = {
      'id': serializedId,
      'kind': _kindToString(kind),
      'name': name,
      'size': size,
    };
    // TODO(sigmund): omit this also when outputUnit.id == 0
    // (most code is by default in the main output unit)
    if (outputUnit != null) res['outputUnit'] = outputUnit.serializedId;
    if (parent != null) res['parent'] = parent.serializedId;
    return res;
  }

  String toString() => '$serializedId $name [$size]';
}

/// Info associated with elements containing executable code (like fields and
/// methods)
abstract class CodeInfo implements Info {
  /// How does this function or field depend on others.
  final List<DependencyInfo> uses = <DependencyInfo>[];
}


/// The entire information produced while compiling a program.
class AllInfo {
  /// Summary information about the program.
  ProgramInfo program;

  /// Information about each library processed by the compiler.
  List<LibraryInfo> libraries = <LibraryInfo>[];

  /// Information about each function (includes methods and getters in any
  /// library)
  List<FunctionInfo> functions = <FunctionInfo>[];

  /// Information about type defs in the program.
  List<TypedefInfo> typedefs = <TypedefInfo>[];

  /// Information about each class (in any library).
  List<ClassInfo> classes = <ClassInfo>[];

  /// Information about fields (in any class).
  List<FieldInfo> fields = <FieldInfo>[];

  /// Information about output units (should be just one entry if not using
  /// deferred loading).
  List<OutputUnitInfo> outputUnits = <OutputUnitInfo>[];

  /// Details about all deferred imports and what files would be loaded when the
  /// import is resolved.
  // TODO(sigmund): use a different format for dump-info. This currently emits
  // the same map that is created for the `--deferred-map` flag.
  Map<String, Map<String, dynamic>> deferredFiles;

  /// A new representation of dependencies form one info to another. An entry in
  /// this map indicates that an Info depends on another (e.g. a function
  /// invokes another). Please note that the data in this field might not be
  /// accurate yet (this is work in progress).
  Map<Info, List<Info>> dependencies = {};

  /// Major version indicating breaking changes in the format. A new version
  /// means that an old deserialization algorithm will not work with the new
  /// format.
  final int version = 3;

  /// Minor version indicating non-breaking changes in the format. A change in
  /// this version number means that the json parsing in this library from a
  /// previous will continue to work after the change. This is typically
  /// increased when adding new entries to the file format.
  // Note: the dump-info.viewer app was written using a json parser version 3.2.
  final int minorVersion = 5;

  AllInfo();

  static AllInfo parseFromJson(Map map) => new _ParseHelper().parseAll(map);

  Map _listAsJsonMap(List<Info> list) {
    var map = <String, Map>{};
    for (var info in list) {
      map['${info.id}'] = info.toJson();
    }
    return map;
  }

  Map _extractHoldingInfo() {
    var map = <String, List>{};
    void helper(CodeInfo info) {
      if (info.uses.isEmpty) return;
      map[info.serializedId] = info.uses.map((u) => u.toJson()).toList();
    }
    functions.forEach(helper);
    fields.forEach(helper);
    return map;
  }

  Map _extractDependencies() {
    var map = <String, List>{};
    dependencies.forEach((k, v) {
      map[k.serializedId] = v.map((i) => i.serializedId).toList();
    });
    return map;
  }

  Map toJson() => {
        'elements': {
          'library': _listAsJsonMap(libraries),
          'class': _listAsJsonMap(classes),
          'function': _listAsJsonMap(functions),
          'typedef': _listAsJsonMap(typedefs),
          'field': _listAsJsonMap(fields),
        },
        'holding': _extractHoldingInfo(),
        'dependencies': _extractDependencies(),
        'outputUnits': outputUnits.map((u) => u.toJson()).toList(),
        'dump_version': version,
        'deferredFiles': deferredFiles,
        'dump_minor_version': '$minorVersion',
        // TODO(sigmund): change viewer to accept an int?
        'program': program.toJson(),
      };

  void accept(InfoVisitor visitor) => visitor.visitAll(this);
}

class ProgramInfo {
  int size;
  String dart2jsVersion;
  DateTime compilationMoment;
  Duration compilationDuration;
  // TODO(sigmund): use Duration.
  int toJsonDuration;
  int dumpInfoDuration;
  bool noSuchMethodEnabled;
  bool minified;

  ProgramInfo(
      {this.size,
      this.dart2jsVersion,
      this.compilationMoment,
      this.compilationDuration,
      this.toJsonDuration,
      this.dumpInfoDuration,
      this.noSuchMethodEnabled,
      this.minified});

  Map toJson() => {
        'size': size,
        'dart2jsVersion': dart2jsVersion,
        'compilationMoment': '$compilationMoment',
        'compilationDuration': '${compilationDuration}',
        'toJsonDuration': toJsonDuration,
        'dumpInfoDuration': '$dumpInfoDuration',
        'noSuchMethodEnabled': noSuchMethodEnabled,
        'minified': minified,
      };

  void accept(InfoVisitor visitor) => visitor.visitProgram(this);
}

// TODO(sigmund): add unit tests.
class _ParseHelper {
  Map<String, Info> registry = {};

  AllInfo parseAll(Map json) {
    var result = new AllInfo();
    var elements = json['elements'];
    result.libraries.addAll(elements['library'].values.map(parseLibrary));
    result.classes.addAll(elements['class'].values.map(parseClass));
    result.functions.addAll(elements['function'].values.map(parseFunction));
    result.fields.addAll(elements['field'].values.map(parseField));
    result.typedefs.addAll(elements['typedef'].values.map(parseTypedef));

    var idMap = {};
    for (var f in result.functions) {
      idMap[f.serializedId] = f;
    }
    for (var f in result.fields) {
      idMap[f.serializedId] = f;
    }

    json['holding'].forEach((k, deps) {
      var src = idMap[k];
      assert (src != null);
      for (var dep in deps) {
        var target = idMap[dep['id']];
        assert (target != null);
        src.uses.add(new DependencyInfo(target, dep['mask']));
      }
    });

    json['dependencies']?.forEach((k, deps) {
      result.dependencies[idMap[k]] = deps.map((d) => idMap[d]).toList();
    });

    result.program = parseProgram(json['program']);
    // todo: version, etc
    return result;
  }

  LibraryInfo parseLibrary(Map json) {
    LibraryInfo result = parseId(json['id']);
    result..name = json['name']
        ..uri = Uri.parse(json['canonicalUri'])
        ..outputUnit = parseId(json['outputUnit'])
        ..size = json['size'];
    for (var child in json['children'].map(parseId)) {
      if (child is FunctionInfo) {
        result.topLevelFunctions.add(child);
      } else if (child is FieldInfo) {
        result.topLevelVariables.add(child);
      } else if (child is ClassInfo) {
        result.classes.add(child);
      } else {
        assert(child is TypedefInfo);
        result.typedefs.add(child);
      }
    }
    return result;
  }

  ClassInfo parseClass(Map json) {
    ClassInfo result = parseId(json['id']);
    result..name = json['name']
        ..parent = parseId(json['parent'])
        ..outputUnit = parseId(json['outputUnit'])
        ..size = json['size']
        ..isAbstract = json['modifiers']['abstract'] == true;
    assert(result is ClassInfo);
    for (var child in json['children'].map(parseId)) {
      if (child is FunctionInfo) {
        result.functions.add(child);
      } else {
        assert(child is FieldInfo);
        result.fields.add(child);
      }
    }
    return result;
  }

  FieldInfo parseField(Map json) {
    FieldInfo result = parseId(json['id']);
    return result..name = json['name']
      ..parent = parseId(json['parent'])
      ..outputUnit = parseId(json['outputUnit'])
      ..size = json['size']
      ..type = json['type']
      ..inferredType = json['inferredType']
      ..code = json['code']
      ..closures = json['children'].map(parseId).toList();
  }

  TypedefInfo parseTypedef(Map json) {
    TypedefInfo result = parseId(json['id']);
    return result..name = json['name']
      ..parent = parseId(json['parent'])
      ..type = json['type']
      ..size = 0;
  }

  ProgramInfo parseProgram(Map json) =>
      new ProgramInfo()..size = json['size'];

  FunctionInfo parseFunction(Map json) {
    FunctionInfo result = parseId(json['id']);
    return result..name = json['name']
      ..parent = parseId(json['parent'])
      ..outputUnit = parseId(json['outputUnit'])
      ..size = json['size']
      ..type = json['type']
      ..returnType = json['returnType']
      ..inferredReturnType = json['inferredReturnType']
      ..parameters = json['parameters'].map(parseParameter).toList()
      ..code = json['code']
      ..sideEffects = json['sideEffects']
      ..modifiers = parseModifiers(json['modifiers'])
      ..closures = json['children'].map(parseId).toList();
  }

  ParameterInfo parseParameter(Map json) =>
      new ParameterInfo(json['name'], json['type'], json['declaredType']);

  FunctionModifiers parseModifiers(Map<String, bool> json) {
    return new FunctionModifiers(
        isStatic: json['static'] == true,
        isConst: json['const'] == true,
        isFactory: json['factory'] == true,
        isExternal: json['external'] == true);
  }

  Info parseId(String serializedId) => registry.putIfAbsent(serializedId, () {
    if (serializedId == null) {
      return null;
    } else if (serializedId.startsWith('function/')) {
      return new FunctionInfo._(serializedId);
    } else if (serializedId.startsWith('library/')) {
      return new LibraryInfo._(serializedId);
    } else if (serializedId.startsWith('class/')) {
      return new ClassInfo._(serializedId);
    } else if (serializedId.startsWith('field/')) {
      return new FieldInfo._(serializedId);
    } else if (serializedId.startsWith('typedef/')) {
      return new TypedefInfo._(serializedId);
    } else if (serializedId.startsWith('outputUnit/')) {
      return new OutputUnitInfo._(serializedId);
    }
    assert(false);
  });
}

/// Info associated with a library element.
class LibraryInfo extends BasicInfo {
  /// Canonical uri that identifies the library.
  Uri uri;

  /// Top level functions defined within the library.
  final List<FunctionInfo> topLevelFunctions = <FunctionInfo>[];

  /// Top level fields defined within the library.
  final List<FieldInfo> topLevelVariables = <FieldInfo>[];

  /// Classes defined within the library.
  final List<ClassInfo> classes = <ClassInfo>[];

  /// Typedefs defined within the library.
  final List<TypedefInfo> typedefs = <TypedefInfo>[];

  static int _id = 0;

  /// Whether there is any information recorded for this library.
  bool get isEmpty =>
      topLevelFunctions.isEmpty && topLevelVariables.isEmpty && classes.isEmpty;

  LibraryInfo(String name, this.uri, OutputUnitInfo outputUnit, int size)
      : super(InfoKind.library, _id++, name, outputUnit, size);

  LibraryInfo._(String serializedId) : super._fromId(serializedId);

  Map toJson() => super.toJson()
    ..addAll({
      'children': []
        ..addAll(topLevelFunctions.map((f) => f.serializedId))
        ..addAll(topLevelVariables.map((v) => v.serializedId))
        ..addAll(classes.map((c) => c.serializedId))
        ..addAll(typedefs.map((t) => t.serializedId)),
      'canonicalUri': '$uri',
    });

  void accept(InfoVisitor visitor) => visitor.visitLibrary(this);
}

/// Information about an output unit. Normally there is just one for the entire
/// program unless the application uses deferred imports, in which case there
/// would be an additional output unit per deferred chunk.
class OutputUnitInfo extends BasicInfo {
  static int _ids = 0;
  OutputUnitInfo(String name, int size)
      : super(InfoKind.outputUnit, _ids++, name, null, size);

  OutputUnitInfo._(String serializedId) : super._fromId(serializedId);

  void accept(InfoVisitor visitor) => visitor.visitOutput(this);
}

/// Information about a class element.
class ClassInfo extends BasicInfo {
  /// Whether the class is abstract.
  bool isAbstract;

  // TODO(sigmund): split static vs instance vs closures
  /// Functions (static or instance) defined in the class.
  final List<FunctionInfo> functions = <FunctionInfo>[];

  /// Fields defined in the class.
  // TODO(sigmund): currently appears to only be populated with instance fields,
  // but this should be fixed.
  final List<FieldInfo> fields = <FieldInfo>[];
  static int _ids = 0;

  ClassInfo(
      {String name, this.isAbstract, OutputUnitInfo outputUnit, int size: 0})
      : super(InfoKind.clazz, _ids++, name, outputUnit, size);

  ClassInfo._(String serializedId) : super._fromId(serializedId);

  Map toJson() => super.toJson()
    ..addAll({
      // TODO(sigmund): change format, include only when abstract is true.
      'modifiers': {'abstract': isAbstract},
      'children': []
        ..addAll(fields.map((f) => f.serializedId))
        ..addAll(functions.map((m) => m.serializedId))
    });

  void accept(InfoVisitor visitor) => visitor.visitClass(this);
}

/// Information about a field element.
class FieldInfo extends BasicInfo with CodeInfo {
  /// The type of the field.
  String type;

  /// The type inferred by dart2js's whole program analysis
  String inferredType;

  /// Nested closures seen in the field initializer.
  List<FunctionInfo> closures;

  /// The actual generated code for the field.
  String code;

  static int _ids = 0;
  FieldInfo(
      {String name,
      int size: 0,
      this.type,
      this.inferredType,
      this.closures,
      this.code,
      OutputUnitInfo outputUnit})
      : super(InfoKind.field, _ids++, name, outputUnit, size);

  FieldInfo._(String serializedId) : super._fromId(serializedId);

  Map toJson() => super.toJson()
    ..addAll({
      'children': closures.map((i) => i.serializedId).toList(),
      'inferredType': inferredType,
      'code': code,
      'type': type,
    });

  void accept(InfoVisitor visitor) => visitor.visitField(this);
}

/// Information about a typedef declaration.
class TypedefInfo extends BasicInfo {
  /// The declared type.
  String type;

  static int _ids = 0;
  TypedefInfo(String name, this.type, OutputUnitInfo outputUnit)
      : super(InfoKind.typedef, _ids++, name, outputUnit, 0);

  TypedefInfo._(String serializedId) : super._fromId(serializedId);

  Map toJson() => super.toJson()..['type'] = '$type';

  void accept(InfoVisitor visitor) => visitor.visitTypedef(this);
}

/// Information about a function or method.
class FunctionInfo extends BasicInfo with CodeInfo {
  static const int TOP_LEVEL_FUNCTION_KIND = 0;
  static const int CLOSURE_FUNCTION_KIND = 1;
  static const int METHOD_FUNCTION_KIND = 2;
  static const int CONSTRUCTOR_FUNCTION_KIND = 3;
  static int _ids = 0;

  /// Kind of function (top-level function, closure, method, or constructor).
  int functionKind;

  /// Modifiers applied to this function.
  FunctionModifiers modifiers;

  /// Nested closures that appear within the body of this function.
  List<FunctionInfo> closures;

  /// The type of this function.
  String type;

  /// The declared return type.
  String returnType;

  /// The inferred return type.
  String inferredReturnType;

  /// Name and type information for each parameter.
  List<ParameterInfo> parameters;

  /// Side-effects.
  // TODO(sigmund): serialize more precisely, not just a string representation.
  String sideEffects;

  /// How many function calls were inlined into this function.
  int inlinedCount;

  /// The actual generated code.
  String code;

  FunctionInfo(
      {String name,
      OutputUnitInfo outputUnit,
      int size: 0,
      this.functionKind,
      this.modifiers,
      this.closures,
      this.type,
      this.returnType,
      this.inferredReturnType,
      this.parameters,
      this.sideEffects,
      this.inlinedCount,
      this.code})
      : super(InfoKind.function, _ids++, name, outputUnit, size);

  FunctionInfo._(String serializedId) : super._fromId(serializedId);

  Map toJson() => super.toJson()
    ..addAll({
      'children': closures.map((i) => i.serializedId).toList(),
      'modifiers': modifiers.toJson(),
      'returnType': returnType,
      'inferredReturnType': inferredReturnType,
      'parameters': parameters.map((p) => p.toJson()).toList(),
      'sideEffects': sideEffects,
      'inlinedCount': inlinedCount,
      'code': code,
      'type': type,
      // Note: version 3.2 of dump-info serializes `uses` in a section called
      // `holding` at the top-level.
    });

  void accept(InfoVisitor visitor) => visitor.visitFunction(this);
}

/// Information about how a dependency is used.
class DependencyInfo {
  /// The dependency, either a FunctionInfo or FieldInfo.
  final Info target;

  /// Either a selector mask indicating how this is used, or 'inlined'.
  // TODO(sigmund): split mask into an enum or something more precise to really
  // describe the dependencies in detail.
  final String mask;

  DependencyInfo(this.target, this.mask);

  Map toJson() => {'id': target.serializedId, 'mask': mask};
}

/// Name and type information about a function parameter.
class ParameterInfo {
  final String name;
  final String type;
  final String declaredType;

  ParameterInfo(this.name, this.type, this.declaredType);

  Map toJson() => {'name': name, 'type': type, 'declaredType': declaredType};
}

/// Modifiers that may apply to methods.
class FunctionModifiers {
  final bool isStatic;
  final bool isConst;
  final bool isFactory;
  final bool isExternal;

  FunctionModifiers(
      {this.isStatic: false,
      this.isConst: false,
      this.isFactory: false,
      this.isExternal: false});

  // TODO(sigmund): exclude false values (requires bumping the format version):
  //   Map toJson() {
  //     var res = <String, bool>{};
  //     if (isStatic) res['static'] = true;
  //     if (isConst) res['const'] = true;
  //     if (isFactory) res['factory'] = true;
  //     if (isExternal) res['external'] = true;
  //     return res;
  //   }
  Map toJson() => {
        'static': isStatic,
        'const': isConst,
        'factory': isFactory,
        'external': isExternal,
      };
}

/// Possible values of the `kind` field in the serialied infos.
enum InfoKind {
  library,
  clazz,
  function,
  field,
  outputUnit,
  typedef,
}

String _kindToString(InfoKind kind) {
  switch(kind) {
    case InfoKind.library: return 'library';
    case InfoKind.clazz: return 'class';
    case InfoKind.function: return 'function';
    case InfoKind.field: return 'field';
    case InfoKind.outputUnit: return 'outputUnit';
    case InfoKind.typedef: return 'typedef';
    default: return null;
  }
}

int _idFromSerializedId(String serializedId) =>
    int.parse(serializedId.substring(serializedId.indexOf('/') + 1));

InfoKind _kindFromSerializedId(String serializedId) =>
    _kindFromString(serializedId.substring(0, serializedId.indexOf('/')));

InfoKind _kindFromString(String kind) {
  switch(kind) {
    case 'library': return InfoKind.library;
    case 'class': return InfoKind.clazz;
    case 'function': return InfoKind.function;
    case 'field': return InfoKind.field;
    case 'outputUnit': return InfoKind.outputUnit;
    case 'typedef': return InfoKind.typedef;
    default: return null;
  }
}

/// A simple visitor for information produced by the dart2js compiler.
class InfoVisitor {
  visitAll(AllInfo info) {}
  visitProgram(ProgramInfo info) {}
  visitLibrary(LibraryInfo info) {}
  visitClass(ClassInfo info) {}
  visitField(FieldInfo info) {}
  visitFunction(FunctionInfo info) {}
  visitTypedef(TypedefInfo info) {}
  visitOutput(OutputUnitInfo info) {}
}

/// A visitor that recursively walks each portion of the program. Because the
/// info representation is redundant, this visitor only walks the structure of
/// the program and skips some redundant links. For example, even though
/// visitAll contains references to functions, this visitor only recurses to
/// visit libraries, then from each library we visit functions and classes, and
/// so on.
class RecursiveInfoVisitor extends InfoVisitor {
  visitAll(AllInfo info) {
    // Note: we don't visit functions, fields, classes, and typedefs because
    // they are reachable from the library info.
    info.libraries.forEach(visitLibrary);
  }

  visitLibrary(LibraryInfo info) {
    info.topLevelFunctions.forEach(visitFunction);
    info.topLevelVariables.forEach(visitField);
    info.classes.forEach(visitClass);
    info.typedefs.forEach(visitTypedef);
  }

  visitClass(ClassInfo info) {
    info.functions.forEach(visitFunction);
    info.fields.forEach(visitField);
  }

  visitField(FieldInfo info) {
    info.closures.forEach(visitFunction);
  }

  visitFunction(FunctionInfo info) {
    info.closures.forEach(visitFunction);
  }
}
