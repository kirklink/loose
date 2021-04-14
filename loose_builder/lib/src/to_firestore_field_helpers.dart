import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:loose_builder/src/null_mode_helper.dart';
import 'package:source_gen/source_gen.dart';

import 'package:loose/annotations.dart';

import 'loose_builder_exception.dart';
import 'recase_helper.dart';
import 'uses_identifier_helper.dart' show usesIdentifier;
import 'constants.dart' show documentIdFieldName;

final _checkForLooseDocument = const TypeChecker.fromRuntime(LooseDocument);
final _checkForLooseMap = const TypeChecker.fromRuntime(LooseMap);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);

Iterable<DartType> _getGenericTypes(DartType type) {
  return type is ParameterizedType ? type.typeArguments : const [];
}

String convertToFirestore(
    ClassElement clazz, int recase, int globalSaveMode, bool suppressWarnings,
    {String parent = '', int nestLevel = 0, bool inList = false}) {
  final classBuffer = StringBuffer();
  classBuffer.writeln('{');

  final classElements = <ClassElement>[];
  classElements.add(clazz);
  for (final superType in clazz.allSupertypes) {
    if (superType.element is ClassElement) {
      classElements.add(superType.element);
    }
  }

  for (final klass in classElements) {
    for (final field in klass.fields) {
      var name = field.name;
      var getterName = '';
      var nullMode = globalSaveMode;
      final nullSuffix = field.type.nullabilitySuffix.index == 0 ? '?' : '';
      ConstantReader? defaultValueReader;
      if (field.isPrivate) {
        if (!_checkForLooseField.hasAnnotationOfExact(field)) {
          if (!suppressWarnings) {
            print(
                '[WARNING] Private field "${field.name}" does not have "privateFieldGetter" annotated and will only be visible in the same library.');
          }
        } else {
          final reader =
              ConstantReader(_checkForLooseField.firstAnnotationOf(field));
          final getter = reader.peek('privateFieldGetter')?.stringValue ?? '';
          if (getter.isEmpty) {
            if (!suppressWarnings) {
              print(
                  '[WARNING] Private field "${field.name}" does not have "privateFieldGetter" annotated and will only be visible in the same library.');
            }
          } else {
            getterName = getter;
          }
        }
      } else {
        if (_checkForLooseField.hasAnnotationOfExact(field)) {
          final reader =
              ConstantReader(_checkForLooseField.firstAnnotationOf(field));
          final getter = reader.peek('privateFieldGetter')?.stringValue ?? '';
          if (getter.isNotEmpty) {
            throw LooseBuilderException(
                'Field "${field.name}" is not private and should not be annotated with "privateFieldGetter" without being ignored.');
          }
        }
      }
      if (field.isStatic || field.isSynthetic) {
        continue;
      }

      if (usesIdentifier(clazz) && (field.name == documentIdFieldName)) {
        continue;
      }

      name = recaseFieldName(recase, name);

      if (_checkForLooseField.hasAnnotationOfExact(field)) {
        final reader =
            ConstantReader(_checkForLooseField.firstAnnotationOf(field));

        final ignore = reader.peek('ignore')?.boolValue ?? false;
        if (ignore) {
          continue;
        }

        final readOnly = reader.peek('readOnly')?.boolValue ?? false;
        if (readOnly) {
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
          name = rename;
        }

        nullMode = getNullMode(reader, 'saveMode');

        defaultValueReader = reader.peek('defaultValue');
      }

      var inheritedName = getterName.isNotEmpty ? getterName : name;
      var inheritedNameDisplay = field.name;
      if (parent.isNotEmpty) {
        inheritedName = '$parent.${getterName.isNotEmpty ? getterName : name}';
        inheritedNameDisplay = '$parent.$name';
      }

      String mode = '';
      if (nullMode == 0) {
        mode = ', useDefaultValue: true';
      } else if (nullMode == 1) {
        mode = ', allowNull: true';
      }

      if (field.type.isDartCoreString) {
        var defaultValue = '';
        if (nullMode == 0) {
          String? d;
          if (defaultValueReader != null) {
            try {
              d = defaultValueReader.stringValue;
            } on FormatException catch (_) {
              final m =
                  'Default value for $inheritedNameDisplay must be String.';
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            defaultValue = ", defaultValue: '$d'";
          }
        }
        classBuffer.writeln(
            "...{'$name' : ToFs.string(e.$inheritedName, '$inheritedNameDisplay'$mode$defaultValue)},");
      } else if (field.type.isDartCoreInt) {
        var defaultValue = '';
        if (nullMode == 0) {
          int? d;
          if (defaultValueReader != null) {
            try {
              d = defaultValueReader.intValue;
            } on FormatException catch (_) {
              final m = 'Default value for $inheritedNameDisplay must be int.';
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            defaultValue = ", defaultValue: $d";
          }
        }
        classBuffer.writeln(
            "...{'$name' : ToFs.integer(e.$inheritedName, '$inheritedNameDisplay'$mode$defaultValue)},");
      } else if (field.type.isDartCoreDouble) {
        var defaultValue = '';
        if (nullMode == 0) {
          double? d;
          if (defaultValueReader != null) {
            try {
              d = defaultValueReader.doubleValue;
            } on FormatException catch (_) {
              final m =
                  'Default value for $inheritedNameDisplay must be double.';
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            defaultValue = ", defaultValue: $d";
          }
        }
        classBuffer.writeln(
            "...{'$name' : ToFs.float(e.$inheritedName, '$inheritedNameDisplay'$mode$defaultValue)},");
      } else if (field.type.isDartCoreBool) {
        var defaultValue = '';
        if (nullMode == 0) {
          bool? d;
          if (defaultValueReader != null) {
            try {
              d = defaultValueReader.boolValue;
            } on FormatException catch (_) {
              final m = 'Default value for $inheritedNameDisplay must be bool.';
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            defaultValue = ", defaultValue: $d";
          }
        }
        classBuffer.writeln(
            "...{'$name' : ToFs.boolean(e.$inheritedName, '$inheritedNameDisplay'$mode$defaultValue)},");
      } else if (field.type.getDisplayString(withNullability: false) ==
          'DateTime') {
        var defaultValue = '';
        if (nullMode == 0) {
          DateTime? d;
          final m = 'Default value for DateTime must be a LooseDatetime';
          if (defaultValueReader != null) {
            try {
              final o = defaultValueReader.objectValue;

              if (o.type.toString() != 'LooseDatetime*') {
                throw LooseBuilderException(m);
              }
              final year = o.getField('year')!.toIntValue()!;
              final month = o.getField('month')!.toIntValue()!;
              final day = o.getField('day')!.toIntValue()!;
              final hour = o.getField('hour')!.toIntValue()!;
              final min = o.getField('minute')!.toIntValue()!;
              final sec = o.getField('second')!.toIntValue()!;
              final msec = o.getField('millisecond')!.toIntValue()!;
              d = DateTime.utc(year, month, day, hour, min, sec, msec);
            } catch (_) {
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            defaultValue = ", defaultValue: '${d.toIso8601String()}'";
          }
        }
        classBuffer.writeln(
            "...{'$name' : ToFs.datetime(e.$inheritedName, '$inheritedNameDisplay'$mode$defaultValue)},");
      } else if (field.type.getDisplayString(withNullability: false) ==
          'Reference') {
        var defaultValue = '';
        if (nullMode == 0) {
          String? d;
          final m =
              'Default value for $inheritedNameDisplay must be Reference.';
          if (defaultValueReader != null) {
            try {
              if (defaultValueReader.objectValue.type.toString() !=
                  'Reference*') {
                throw LooseBuilderException(m);
              }
              d = defaultValueReader.objectValue
                  .getField('name')!
                  .toStringValue();
            } catch (_) {
              throw LooseBuilderException(m);
            }
          }
          if (d != null) {
            defaultValue = ", defaultValue: '$d'";
          }
        }
        classBuffer.writeln(
            "...{'$name' : ToFs.reference(e.$inheritedName, '$inheritedNameDisplay'$mode$defaultValue)},");
        // Class
      } else if (_checkForLooseMap.hasAnnotationOfExact(field.type.element!) ||
          _checkForLooseDocument.hasAnnotationOfExact(field.type.element!)) {
        if (field.type.element is! ClassElement) {
          throw LooseBuilderException(
              'LooseDocument or LooseMap must only annotate classes. Field "${field.name}" is not a class.');
        }

        if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element!)) {
          nestLevel = nestLevel + 1;
        }

        // if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
        //   nestLevel = nestLevel + 1;
        // }
        //
        // var defaultValue = '';
        if (nullMode == 0) {
          final m = '$inheritedNameDisplay cannot have a default value.';
          if (defaultValueReader != null) {
            throw LooseBuilderException(m);
          }

          // defaultValue = ", defaultValue: const {}";
        }
        classBuffer.write(
            "...{'$name' : ToFs.map(${convertToFirestore(field.type.element as ClassElement, recase, globalSaveMode, suppressWarnings, parent: inheritedName + nullSuffix, nestLevel: nestLevel)}, '$inheritedNameDisplay'$mode)},");
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
        listBuf.write(
            "...{'$name' : ToFs.list(e.$inheritedName$nullSuffix.map((e) => ");
        if (elementType.isDartCoreString) {
          var defaultValue = '';
          if (nullMode == 0) {
            String? d;
            if (defaultValueReader != null) {
              try {
                d = defaultValueReader.stringValue;
              } on FormatException catch (_) {
                final m =
                    'Default value for $inheritedNameDisplay must be String.';
                throw LooseBuilderException(m);
              }
            }
            if (d != null) {
              defaultValue = ", defaultValue: '$d'";
            }
          }
          listBuf.write(
              "ToFs.string(e, '$inheritedNameDisplay'$mode$defaultValue)");
        } else if (elementType.isDartCoreInt) {
          var defaultValue = '';
          if (nullMode == 0) {
            int? d;
            if (defaultValueReader != null) {
              try {
                d = defaultValueReader.intValue;
              } on FormatException catch (_) {
                final m =
                    'Default value for $inheritedNameDisplay must be int.';
                throw LooseBuilderException(m);
              }
            }
            if (d != null) {
              defaultValue = ", defaultValue: $d";
            }
          }
          listBuf.write(
              "ToFs.integer(e, '$inheritedNameDisplay'$mode$defaultValue)");
        } else if (elementType.isDartCoreDouble) {
          var defaultValue = '';
          if (nullMode == 0) {
            double? d;
            if (defaultValueReader != null) {
              try {
                d = defaultValueReader.doubleValue;
              } on FormatException catch (_) {
                final m =
                    'Default value for $inheritedNameDisplay must be double.';
                throw LooseBuilderException(m);
              }
            }
            if (d != null) {
              defaultValue = ", defaultValue: $d";
            }
          }
          listBuf.write(
              "ToFs.float(e, '$inheritedNameDisplay'$mode$defaultValue)");
        } else if (elementType.isDartCoreBool) {
          var defaultValue = '';
          if (nullMode == 0) {
            bool? d;
            if (defaultValueReader != null) {
              try {
                d = defaultValueReader.boolValue;
              } on FormatException catch (_) {
                final m =
                    'Default value for $inheritedNameDisplay must be bool.';
                throw LooseBuilderException(m);
              }
            }
            if (d != null) {
              defaultValue = ", defaultValue: $d";
            }
          }
          listBuf.write(
              "ToFs.boolean(e, '$inheritedNameDisplay'$mode$defaultValue)");
        } else if (elementType.getDisplayString(withNullability: false) ==
            'DateTime') {
          var defaultValue = '';
          if (nullMode == 0) {
            DateTime? d;
            final m = 'Default value for DateTime must be a LooseDatetime';
            if (defaultValueReader != null) {
              try {
                final o = defaultValueReader.objectValue;
                if (o.type.toString() != 'LooseDatetime*') {
                  throw LooseBuilderException(m);
                }
                final year = o.getField('year')!.toIntValue()!;
                final month = o.getField('month')!.toIntValue()!;
                final day = o.getField('day')!.toIntValue()!;
                final hour = o.getField('hour')!.toIntValue()!;
                final min = o.getField('minute')!.toIntValue()!;
                final sec = o.getField('second')!.toIntValue()!;
                final msec = o.getField('millisecond')!.toIntValue()!;
                d = DateTime.utc(year, month, day, hour, min, sec, msec);
              } catch (_) {
                throw LooseBuilderException(m);
              }
            }
            if (d != null) {
              defaultValue = ", defaultValue: '${d.toIso8601String()}'";
            }
          }
          listBuf.write(
              "ToFs.datetime(e, '$inheritedNameDisplay'$mode$defaultValue)");
        } else if (elementType.getDisplayString(withNullability: false) ==
            'Reference') {
          var defaultValue = '';
          if (nullMode == 0) {
            String? d;
            final m =
                'Default value for $inheritedNameDisplay must be Reference.';
            if (defaultValueReader != null) {
              try {
                if (defaultValueReader.objectValue.type.toString() !=
                    'Reference*') {
                  throw LooseBuilderException(m);
                }
                d = defaultValueReader.objectValue
                    .getField('name')!
                    .toStringValue();
              } catch (_) {
                throw LooseBuilderException(m);
              }
            }
            if (d != null) {
              defaultValue = ", defaultValue: '$d'";
            }
          }
          listBuf.write(
              "ToFs.reference(e, '$inheritedNameDisplay'$mode$defaultValue)");
        } else if (_checkForLooseMap
                .hasAnnotationOfExact(elementType.element!) ||
            _checkForLooseDocument.hasAnnotationOfExact(elementType.element!)) {
          if (elementType.element is! ClassElement) {
            throw LooseBuilderException(
                'LooseDocument or LooseMap must only annotate classes. Field elements "${elementType.getDisplayString(withNullability: false)}" are not user defined classes.');
          }
          listBuf.write(
              "ToFs.map(${convertToFirestore(elementType.element as ClassElement, recase, globalSaveMode, suppressWarnings, nestLevel: 0, inList: true)}, '$inheritedNameDisplay'$mode)");
        }
        listBuf.write(").toList(), '$inheritedNameDisplay'$mode)},");
        classBuffer.writeln(listBuf.toString());
      }
    }
  }
  classBuffer.writeln('}');
  return classBuffer.toString();
}
