import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:loose_builder/src/null_mode_helper.dart';
import 'package:source_gen/source_gen.dart';

import 'package:loose/annotations.dart';

import 'loose_builder_exception.dart';
import 'recase_helper.dart';
import 'constants.dart' show documentIdFieldName;
import 'uses_identifier_helper.dart' show usesIdentifier;

final _checkForLooseDocument = const TypeChecker.fromRuntime(LooseDocument);
final _checkForLooseMap = const TypeChecker.fromRuntime(LooseMap);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);

Iterable<DartType> _getGenericTypes(DartType type) {
  return type is ParameterizedType ? type.typeArguments : const [];
}

String convertFromFirestore(ClassElement clazz, int recase, int globalReadMode,
    {String parent = '', int nestLevel = 0, bool inList = false}) {
  final classBuffer = StringBuffer();

  final constructorFields = <String>[];
  bool hasLooseConstructor = false;

  clazz.constructors.forEach((c) {
    if (c.name == 'loose') {
      hasLooseConstructor = true;
      c.parameters.forEach((p) {
        if (p.isOptionalPositional) {
          constructorFields.add('${p.name}');
        }
      });
    }
  });

  final constructorBuf = StringBuffer();
  if (nestLevel > 0 ||
      inList ||
      _checkForLooseMap.hasAnnotationOfExact(clazz)) {
    constructorBuf
        .write('${clazz.name}${hasLooseConstructor ? '.loose' : ''}(');
  } else {
    constructorBuf.write(
        "final e = ${clazz.name}${hasLooseConstructor ? '.loose' : ''}(");
  }

  final classElements = <ClassElement>[];
  classElements.add(clazz);
  for (final superType in clazz.allSupertypes) {
    classElements.add(superType.element);
  }
  final converters = <String, String>{};

  for (final klass in classElements) {
    for (final field in klass.fields) {
      if (field.isStatic || field.isSynthetic) {
        continue;
      }
      if (usesIdentifier(clazz) && (field.name == documentIdFieldName)) {
        continue;
      }

      var fieldName = field.name;

      var dbname = recaseFieldName(recase, fieldName);
      var nullMode = globalReadMode;
      ConstantReader defaultValueReader;
      if (_checkForLooseField.hasAnnotationOfExact(field)) {
        final reader =
            ConstantReader(_checkForLooseField.firstAnnotationOf(field));

        final ignore = reader.peek('ignore')?.boolValue ?? false;
        if (ignore) {
          continue;
        }

        if ((reader.peek('ignoreIfNested')?.boolValue ?? false) &&
            nestLevel > 0) {
          continue;
        }

        if ((reader.peek('ignoreInLists')?.boolValue ?? false) && inList) {
          continue;
        }

        final rename = reader.peek('name')?.stringValue ?? '';
        if (rename.isNotEmpty) {
          dbname = rename;
        }
        if (reader.peek('readMode') != null) {
          nullMode = getNullMode(reader, 'readMode');
        }

        defaultValueReader = reader.peek('defaultValue');
      }

      String displayName;
      if (parent.isEmpty) {
        displayName = '${field.name}';
      } else {
        displayName = '$parent.${field.name}';
      }

      String mode = '';
      if (nullMode == 1) {
        mode = ', allowNull: true';
      }

      var converter = '';
      if (field.type.isDartCoreString) {
        if (nullMode == 0) {
          String d;
          if (defaultValueReader != null) {
            try {
              d = defaultValueReader.stringValue;
            } on FormatException catch (_) {
              final m = 'Default value for $displayName must be String.';
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            mode = ", defaultValue: '$d'";
          }
          converter = "FromFs.string(m['$dbname']$mode)";
        } else {
          converter =
              "FromFs.stringNull(m['${dbname}'], name: '${displayName}'$mode)";
        }
      } else if (field.type.isDartCoreInt) {
        if (nullMode == 0) {
          int d;
          if (defaultValueReader != null) {
            try {
              d = defaultValueReader.intValue;
            } on FormatException catch (_) {
              final m = 'Default value for $displayName must be int.';
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            mode = ", defaultValue: $d";
          }
          converter = "FromFs.integer(m['$dbname']$mode)";
        } else {
          converter =
              "FromFs.integerNull(m['${dbname}'], name: '${displayName}'$mode)";
        }
      } else if (field.type.isDartCoreDouble) {
        if (nullMode == 0) {
          double d;
          if (defaultValueReader != null) {
            try {
              d = defaultValueReader.doubleValue;
            } on FormatException catch (_) {
              final m = 'Default value for $displayName must be double.';
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            mode = ", defaultValue: $d";
          }
          converter = "FromFs.float(m['$dbname']$mode)";
        } else {
          converter =
              "FromFs.floatNull(m['${dbname}'], name: '${displayName}'$mode)";
        }
      } else if (field.type.isDartCoreBool) {
        if (nullMode == 0) {
          bool d;
          if (defaultValueReader != null) {
            try {
              d = defaultValueReader.boolValue;
            } on FormatException catch (_) {
              final m = 'Default value for $displayName must be bool.';
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            mode = ", defaultValue: $d";
          }
          converter = "FromFs.boolean(m['$dbname']$mode)";
        } else {
          converter =
              "FromFs.booleanNull(m['${dbname}'], name: '${displayName}'$mode)";
        }
      } else if (field.type.getDisplayString(withNullability: false) ==
          'DateTime') {
        if (nullMode == 0) {
          DateTime d;
          final m = 'Default value for DateTime must be a ConstantDateTime';
          if (defaultValueReader != null) {
            try {
              final o = defaultValueReader.objectValue;
              if (o.type.toString() != 'ConstantDateTime*') {
                throw LooseBuilderException(m);
              }
              final year = o.getField('year').toIntValue();
              final month = o.getField('month').toIntValue();
              final day = o.getField('day').toIntValue();
              final hour = o.getField('hour').toIntValue();
              final min = o.getField('minute').toIntValue();
              final sec = o.getField('second').toIntValue();
              final msec = o.getField('millisecond').toIntValue();
              d = DateTime(year, month, day, hour, min, sec, msec);
            } catch (_) {
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            mode = ", defaultValue: '$d'";
          }
          converter = "FromFs.datetime(m['$dbname']$mode)";
        } else {
          converter =
              "FromFs.datetimeNull(m['${dbname}'], name: '${displayName}'$mode)";
        }
      } else if (field.type.getDisplayString(withNullability: false) ==
          'Reference') {
        if (nullMode == 0) {
          String d;
          final m = 'Default value for $displayName must be Reference.';
          if (defaultValueReader != null) {
            try {
              if (defaultValueReader.objectValue.type.toString() !=
                  'Reference*') {
                throw LooseBuilderException(m);
              }
              d = defaultValueReader.objectValue
                  .getField('name')
                  .toStringValue();
            } catch (_) {
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            mode = ", defaultValue: '$d'";
          }
          converter = "FromFs.reference(m['$dbname']$mode)";
        } else {
          converter =
              "FromFs.referenceNull(m['${dbname}'], name: '${displayName}'$mode)";
        }
        // Map
      } else if (_checkForLooseMap.hasAnnotationOfExact(field.type.element) ||
          _checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
        if (field.type.element is! ClassElement) {
          throw LooseBuilderException(
              'LooseDocument or LooseMap must only annotate classes. Field "${field.name}" is not a class.');
        }

        if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
          nestLevel = nestLevel + 1;
        }

        final mapBuf = StringBuffer();
        if (nullMode == 0) {
          final m = '$displayName cannot have a default value.';
          if (defaultValueReader != null) {
            throw LooseBuilderException(m);
          }

          mode = ", defaultValue: const {}";

          mapBuf.writeln("FromFs.map(m['${dbname}'], (m) => ");
          mapBuf.writeln(
              '${convertFromFirestore(field.type.element, recase, globalReadMode, parent: displayName, nestLevel: nestLevel)}');
          mapBuf.writeln("$mode)");
          converter = mapBuf.toString();
        } else {
          mapBuf.writeln("FromFs.mapNull(m['${dbname}'], (m) => ");
          mapBuf.writeln(
              '${convertFromFirestore(field.type.element, recase, globalReadMode, parent: displayName, nestLevel: nestLevel)}');
          mapBuf.writeln(", name: '${displayName}'$mode)");
          converter = mapBuf.toString();
        }

        // List
      } else if (field.type.isDartCoreList) {
        final elementTypes = _getGenericTypes(field.type);
        if (elementTypes.isEmpty) {
          throw LooseBuilderException(
              'The element type of ${field.name} should be specified.');
        }
        if (elementTypes.first.isDartCoreList) {
          throw LooseBuilderException(
              'Cannot nest a list within the list ${field.name}.');
        }
        if (elementTypes.first.isDartCoreMap) {
          throw LooseBuilderException(
              'Maps within the list ${field.name} must be implemented by using a class annotated with @LooseMap');
        }
        final elementType = elementTypes.first;
        final listBuf = StringBuffer();

        var nullFunction = '';
        var nullOk = '';
        if (nullMode == 1 || nullMode == 2) {
          nullFunction = 'Null';
        }
        if (nullMode == 1) {
          nullOk = ', allowNull: true';
        }
        listBuf.write("FromFs.list$nullFunction(m['${dbname}'], ");

        if (elementType.isDartCoreString) {
          listBuf.write('(e) => FromFs.string$nullFunction(e$nullOk)');
        } else if (elementType.isDartCoreInt) {
          listBuf.write('(e) => FromFs.integer$nullFunction(e$nullOk)');
        } else if (elementType.isDartCoreDouble) {
          listBuf.write('(e) => FromFs.float$nullFunction(e$nullOk)');
        } else if (elementType.isDartCoreBool) {
          listBuf.write('(e) => FromFs.boolean$nullFunction(e$nullOk)');
        } else if (elementType.getDisplayString(withNullability: false) ==
            'DateTime') {
          listBuf.write('(e) => FromFs.datetime$nullFunction(e$nullOk)');
        } else if (elementType.getDisplayString(withNullability: false) ==
            'Reference') {
          listBuf.write('(e) => FromFs.reference$nullFunction(e$nullOk)');
        } else if (_checkForLooseMap
                .hasAnnotationOfExact(elementType.element) ||
            _checkForLooseDocument.hasAnnotationOfExact(elementType.element)) {
          if (elementType.element is! ClassElement) {
            throw LooseBuilderException(
                'LooseDocument or LooseMap must only annotate classes. Field "${field.name}" is not a class.');
          }
          if (nullMode == 0) {
            final m = '$displayName cannot have a default value.';
            if (defaultValueReader != null) {
              throw LooseBuilderException(m);
            }
          }

          mode = mode = ", defaultValue: const {}";

          listBuf.write("(e) => FromFs.map(e, (m) => ");
          listBuf.writeln(
              '${convertFromFirestore(elementType.element, recase, globalReadMode, nestLevel: 0, inList: true)}');
          listBuf.write("$mode)");
        } else {
          listBuf.write("(e) => FromFs.mapNull(e, (m) => ");
          listBuf.writeln(
              '${convertFromFirestore(elementType.element, recase, globalReadMode, nestLevel: 0, inList: true)}');
          listBuf.write(", name: '${displayName}'$mode)");
        }
        if (nullMode == 0) {
          mode = mode = ", defaultValue: const []";
          listBuf.write("$mode)");
        } else {
          listBuf.write(", name: '${displayName}'$mode)");
        }

        converter = listBuf.toString();
      }

      if (constructorFields.contains(field.name)) {
        converters[field.name] = converter;
      } else {
        classBuffer.write('..${field.name} = ');
        classBuffer.write(converter);
      }
    }
  }
  constructorFields.forEach((e) {
    constructorBuf.writeln(converters[e]);
    constructorBuf.writeln(',');
  });

  constructorBuf.writeln(')');
  final result = constructorBuf.toString() + classBuffer.toString();
  // print(result);
  return result;
}
