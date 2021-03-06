import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
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

String convertToFirestore(ClassElement clazz, int recase, bool globalAllowNull,
    bool globalUseDefaultValues, bool suppressWarnings,
    {String parent = '',
    bool parentAllowNull = false,
    int nestLevel = 0,
    bool inList = false}) {
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
      if (field.isPrivate) {
        if (!_checkForLooseField.hasAnnotationOfExact(field)) {
          if (!suppressWarnings) {
            print(
                '[WARNING] Private field "${field.name}" does not have "getter" annotated and will only be visible in the same library.');
          }
        } else {
          final reader =
              ConstantReader(_checkForLooseField.firstAnnotationOf(field));
          final getter = reader.peek('getter')?.stringValue ?? '';
          if (getter.isEmpty) {
            if (!suppressWarnings) {
              print(
                  '[WARNING] Private field "${field.name}" does not have "getter" annotated and will only be visible in the same library.');
            }
          } else {
            getterName = getter;
          }
        }
      } else {
        if (_checkForLooseField.hasAnnotationOfExact(field)) {
          final reader =
              ConstantReader(_checkForLooseField.firstAnnotationOf(field));
          final getter = reader.peek('getter')?.stringValue ?? '';
          if (getter.isNotEmpty) {
            throw LooseBuilderException(
                'Field "${field.name}" is not private and should not be annoted with "getter" without being ignored.');
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
      // if (field.isPrivate) {
      //   name = name.replaceFirst('_', '');
      // }
      var allowNull = globalAllowNull;
      var useDefaultValue = globalUseDefaultValues;

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

        if ((reader.peek('allowNull')?.boolValue ?? false) &&
            (reader.peek('useDefaultValue')?.boolValue ?? false)) {
          throw LooseBuilderException(
              'allowNull and useDefaultValue should not be used together on LooseField ${field.name}.');
        }

        if (reader.peek('allowNull')?.boolValue ?? false) {
          allowNull = true;
          useDefaultValue = false;
        }

        if (reader.peek('useDefaultValue')?.boolValue ?? false) {
          allowNull = false;
          useDefaultValue = true;
        }
      }

      var inheritedName = getterName.isNotEmpty ? getterName : name;
      var inheritedNameDisplay = field.name;
      if (parent.isNotEmpty) {
        inheritedName = '$parent?.${getterName.isNotEmpty ? getterName : name}';
        inheritedNameDisplay = '$parent.$name';
      }
      // final inheritedNameDisplay = inheritedName.replaceAll('?', '');

      String mode = '';
      if (useDefaultValue) {
        mode = ', useDefaultValue: true';
      } else if (allowNull) {
        mode = ', allowNull: true';
      } else if (parentAllowNull) {
        mode = ', allowNull: (e?.$parent == null)';
      }

      if (field.type.isDartCoreString) {
        classBuffer.writeln(
            "...{'$name' : ToFs.string(e?.$inheritedName, '$inheritedNameDisplay'$mode)},");
      } else if (field.type.isDartCoreInt) {
        classBuffer.writeln(
            "...{'$name' : ToFs.integer(e?.$inheritedName, '$inheritedNameDisplay'$mode)},");
      } else if (field.type.isDartCoreDouble) {
        classBuffer.writeln(
            "...{'$name' : ToFs.float(e?.$inheritedName, '$inheritedNameDisplay'$mode)},");
      } else if (field.type.isDartCoreBool) {
        classBuffer.writeln(
            "...{'$name' : ToFs.boolean(e?.$inheritedName, '$inheritedNameDisplay'$mode)},");
      } else if (field.type.getDisplayString(withNullability: false) ==
          'DateTime') {
        classBuffer.writeln(
            "...{'$name' : ToFs.datetime(e?.$inheritedName, '$inheritedNameDisplay'$mode)},");
      } else if (field.type.getDisplayString(withNullability: false) ==
          'Reference') {
        classBuffer.writeln(
            "...{'$name' : ToFs.reference(e?.$inheritedName, '$inheritedNameDisplay'$mode)},");
        // Class
      } else if (_checkForLooseMap.hasAnnotationOfExact(field.type.element) ||
          _checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
        if (field.type.element is! ClassElement) {
          throw LooseBuilderException(
              'LooseDocument or LooseMap must only annotate classes. Field "${field.name}" is not a class.');
        }

        var childAllowNulls = false;
        var childUseDefaultValues = false;
        if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
          final reader = ConstantReader(
              _checkForLooseDocument.firstAnnotationOf(field.type.element));
          final thisAllowNulls = reader.peek('allowNulls')?.boolValue ?? false;
          final thisUseDefaultValue =
              reader.peek('useDefaultValue')?.boolValue ?? false;
          childAllowNulls = thisAllowNulls ? true : allowNull;
          childUseDefaultValues = thisUseDefaultValue ? true : allowNull;
          nestLevel = nestLevel + 1;
        }

        if (_checkForLooseMap.hasAnnotationOfExact(field.type.element)) {
          final reader = ConstantReader(
              _checkForLooseMap.firstAnnotationOf(field.type.element));
          final thisAllowNulls = reader.peek('allowNulls')?.boolValue ?? false;
          final thisUseDefaultValue =
              reader.peek('useDefaultValue')?.boolValue ?? false;
          childAllowNulls = thisAllowNulls ? true : allowNull;
          childUseDefaultValues = thisUseDefaultValue ? true : allowNull;
        }
        if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
          nestLevel = nestLevel + 1;
        }
        classBuffer.write(
            "...{'$name' : ToFs.map(${convertToFirestore(field.type.element, recase, childAllowNulls, childUseDefaultValues, suppressWarnings, parent: inheritedName, parentAllowNull: (allowNull || parentAllowNull), nestLevel: nestLevel)}, '$inheritedNameDisplay'$mode)},");
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
        listBuf.write("...{'$name' : ToFs.list(e?.$inheritedName?.map((e) => ");
        if (elementType.isDartCoreString) {
          listBuf.write("ToFs.string(e, '$inheritedNameDisplay')");
        } else if (elementType.isDartCoreInt) {
          listBuf.write("ToFs.integer(e, '$inheritedNameDisplay')");
        } else if (elementType.isDartCoreDouble) {
          listBuf.write("ToFs.float(e, '$inheritedNameDisplay')");
        } else if (elementType.isDartCoreBool) {
          listBuf.write("ToFs.boolean(e, '$inheritedNameDisplay')");
        } else if (elementType.getDisplayString(withNullability: false) ==
            'DateTime') {
          listBuf.write("ToFs.datetime(e, '$inheritedNameDisplay')");
        } else if (elementType.getDisplayString(withNullability: false) ==
            'Reference') {
          listBuf.write("ToFs.reference(e, '$inheritedNameDisplay')");
        } else if (_checkForLooseMap
                .hasAnnotationOfExact(elementType.element) ||
            _checkForLooseDocument.hasAnnotationOfExact(elementType.element)) {
          if (elementType.element is! ClassElement) {
            throw LooseBuilderException(
                'LooseDocument or LooseMap must only annotate classes. Field elements "${elementType.getDisplayString(withNullability: false)}" are not user defined classes.');
          }
          var childAllowNulls = false;
          var childUseDefaultValues = false;
          if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
            final reader = ConstantReader(
                _checkForLooseDocument.firstAnnotationOf(field.type.element));
            final thisAllowNulls =
                reader.peek('allowNulls')?.boolValue ?? false;
            final thisUseDefaultValue =
                reader.peek('useDefaultValue')?.boolValue ?? false;
            childAllowNulls = thisAllowNulls ? true : allowNull;
            childUseDefaultValues = thisUseDefaultValue ? true : allowNull;
          }

          if (_checkForLooseMap.hasAnnotationOfExact(field.type.element)) {
            final reader = ConstantReader(
                _checkForLooseMap.firstAnnotationOf(field.type.element));
            final thisAllowNulls =
                reader.peek('allowNulls')?.boolValue ?? false;
            final thisUseDefaultValue =
                reader.peek('useDefaultValue')?.boolValue ?? false;
            childAllowNulls = thisAllowNulls ? true : allowNull;
            childUseDefaultValues = thisUseDefaultValue ? true : allowNull;
          }
          listBuf.write(
              "ToFs.map(${convertToFirestore(elementType.element, recase, childAllowNulls, childUseDefaultValues, suppressWarnings, nestLevel: 0, inList: true)}, '$inheritedNameDisplay'$mode)");
        }
        listBuf.write(")?.toList(), '$inheritedNameDisplay'$mode)},");
        classBuffer.writeln(listBuf.toString());
      }
    }
  }
  classBuffer.writeln('}');
  return classBuffer.toString();
}
