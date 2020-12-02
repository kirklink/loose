import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'package:loose/annotations.dart';

import 'package:loose_builder/src/loose_builder_exception.dart';
import 'package:loose_builder/src/recase_helper.dart';
import 'package:loose_builder/src/constants.dart' show documentIdFieldName;
import 'package:loose_builder/src/uses_identifier_helper.dart'
    show usesIdentifier;

final _checkForLooseDocument = const TypeChecker.fromRuntime(LooseDocument);
final _checkForLooseMap = const TypeChecker.fromRuntime(LooseMap);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);

Iterable<DartType> _getGenericTypes(DartType type) {
  return type is ParameterizedType ? type.typeArguments : const [];
}

String convertFromFirestore(ClassElement clazz, int recase,
    bool globalAllowNulls, bool globalReadonlyNulls,
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
  if (nestLevel == 0) {
    constructorBuf.write(
        "final e = ${clazz.name}${hasLooseConstructor ? '.loose' : ''}(");
  } else {
    constructorBuf
        .write('${clazz.name}${hasLooseConstructor ? '.loose' : ''}(');
  }

  // final constructorStatements = <String>[];

  final classElements = <ClassElement>[];
  classElements.add(clazz);
  for (final superType in clazz.allSupertypes) {
    classElements.add(superType.element);
  }
  // classElements.forEach((e) => print(e.displayName));
  // for (final klass in classElements) {
  //   for (final field in klass.fields) {
  //     print('class: ${klass.type.getDisplayString(withNullability: false)}');
  //     print('field: $field');
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
      if (field.isPrivate) {
        fieldName = fieldName.replaceFirst('_', '');
      }

      var dbname = recaseFieldName(recase, fieldName);

      var allowNull = globalAllowNulls || globalReadonlyNulls;

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
        final readNull = reader.peek('readonlyNull')?.boolValue;
        allowNull = (reader.peek('allowNull')?.boolValue ?? readNull) ??
            globalAllowNulls;
      }

      String displayName;
      if (parent.isEmpty) {
        displayName = '${field.name}';
      } else {
        displayName = '$parent.${field.name}';
      }

      String mode = '';
      if (allowNull) {
        mode = ', allowNull: true';
      }

      // final fieldBuf = StringBuffer();
      // if (!constructorFields.contains(field.name)) {

      // }

      var converter = '';
      if (field.type.isDartCoreString) {
        converter =
            "FromFs.string(m['${dbname}'], name: '${displayName}'$mode)";
      } else if (field.type.isDartCoreInt) {
        converter =
            "FromFs.integer(m['${dbname}'], name: '${displayName}'$mode)";
      } else if (field.type.isDartCoreDouble) {
        converter = "FromFs.float(m['${dbname}'], name: '${displayName}'$mode)";
      } else if (field.type.isDartCoreBool) {
        converter =
            "FromFs.boolean(m['${dbname}'], name: '${displayName}'$mode)";
      } else if (field.type.getDisplayString(withNullability: false) ==
          'DateTime') {
        converter =
            "FromFs.datetime(m['${dbname}'], name: '${displayName}'$mode)";
      } else if (field.type.getDisplayString(withNullability: false) ==
          'Reference') {
        converter =
            "FromFs.reference(m['${dbname}'], name: '${displayName}'$mode)";

        // Map
      } else if (_checkForLooseMap.hasAnnotationOfExact(field.type.element) ||
          _checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
        if (field.type.element is! ClassElement) {
          throw LooseBuilderException(
              'LooseDocument or LooseMap must only annotate classes. Field "${field.name}" is not a class.');
        }

        var childAllowNulls = false;
        var childReadonlyNulls = false;
        if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
          final reader = ConstantReader(
              _checkForLooseDocument.firstAnnotationOf(field.type.element));
          final thisAllowNulls = reader.peek('allowNulls')?.boolValue ?? false;
          final thisReadonlyNulls =
              reader.peek('readonlyNulls')?.boolValue ?? false;
          childAllowNulls = thisAllowNulls ? true : allowNull;
          childReadonlyNulls = thisReadonlyNulls ? true : allowNull;
          nestLevel = nestLevel + 1;
        }

        if (_checkForLooseMap.hasAnnotationOfExact(field.type.element)) {
          final reader = ConstantReader(
              _checkForLooseMap.firstAnnotationOf(field.type.element));
          final thisAllowNulls = reader.peek('allowNulls')?.boolValue ?? false;
          final thisReadonlyNulls =
              reader.peek('readonlyNulls')?.boolValue ?? false;
          childAllowNulls = thisAllowNulls ? true : allowNull;
          childReadonlyNulls = thisReadonlyNulls ? true : allowNull;
        }

        final mapBuf = StringBuffer();
        mapBuf.writeln("FromFs.map(m['${dbname}'], (m) => ");
        mapBuf.writeln(
            '${convertFromFirestore(field.type.element, recase, childAllowNulls, childReadonlyNulls, parent: displayName, nestLevel: nestLevel)}');
        mapBuf.writeln(", name: '${displayName}'$mode)");
        converter = mapBuf.toString();
        // classBuffer.write(mapBuf.toString());

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
        listBuf.write("FromFs.list(m['${field.name}'], ");
        if (elementType.isDartCoreString) {
          listBuf.write('(e) => FromFs.string(e, allowNull: true)');
        } else if (elementType.isDartCoreInt) {
          listBuf.write('(e) => FromFs.integer(e, allowNull: true)');
        } else if (elementType.isDartCoreDouble) {
          listBuf.write('(e) => FromFs.float(e, allowNull: true)');
        } else if (elementType.isDartCoreBool) {
          listBuf.write('(e) => FromFs.boolean(e, allowNull: true)');
        } else if (elementType.getDisplayString(withNullability: false) ==
            'DateTime') {
          listBuf.write('(e) => FromFs.datetime(e, allowNull: true)');
        } else if (elementType.getDisplayString(withNullability: false) ==
            'Reference') {
          listBuf.write('(e) => FromFs.reference(e, allowNull: true)');
        } else if (_checkForLooseMap
                .hasAnnotationOfExact(elementType.element) ||
            _checkForLooseDocument.hasAnnotationOfExact(elementType.element)) {
          if (elementType.element is! ClassElement) {
            throw LooseBuilderException(
                'LooseDocument or LooseMap must only annotate classes. Field "${field.name}" is not a class.');
          }

          var childAllowNulls = false;
          var childReadonlyNulls = false;
          if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
            final reader = ConstantReader(
                _checkForLooseDocument.firstAnnotationOf(field.type.element));
            final thisAllowNulls =
                reader.peek('allowNulls')?.boolValue ?? false;
            final thisReadonlyNulls =
                reader.peek('readonlyNulls')?.boolValue ?? false;
            childAllowNulls = thisAllowNulls ? true : allowNull;
            childReadonlyNulls = thisReadonlyNulls ? true : allowNull;
          }

          if (_checkForLooseMap.hasAnnotationOfExact(field.type.element)) {
            final reader = ConstantReader(
                _checkForLooseMap.firstAnnotationOf(field.type.element));
            final thisAllowNulls =
                reader.peek('allowNulls')?.boolValue ?? false;
            final thisReadonlyNulls =
                reader.peek('readonlyNulls')?.boolValue ?? false;
            childAllowNulls = thisAllowNulls ? true : allowNull;
            childReadonlyNulls = thisReadonlyNulls ? true : allowNull;
          }

          listBuf.write("(e) => FromFs.map(e, (m) => ");
          listBuf.writeln(
              '${convertFromFirestore(elementType.element, recase, childAllowNulls, childReadonlyNulls, nestLevel: 0, inList: true)}');
          listBuf.write(", name: '${displayName}'$mode)");
        }
        listBuf.write(", name: '${displayName}'$mode)");
        converter = listBuf.toString();
        // classBuffer.writeln(listBuf.toString());
      }

      if (constructorFields.contains(field.name)) {
        converters[field.name] = converter;
        // constructorBuf.write('${field.name}: ');

      } else {
        classBuffer.write('..${field.name} = ');
        classBuffer.write(converter);
      }
    }

    // constructorBuf.writeAll([converter, ',']);
  }
  constructorFields.forEach((e) {
    constructorBuf.writeln(converters[e]);
    constructorBuf.writeln(',');
  });

  // clazz.constructors.forEach((c) {
  //   if (c.isDefaultConstructor) {
  //     c.parameters.forEach((p) {
  //       if (p.isOptionalNamed) {
  //         constructorBuf.write('${p.name}: ');
  //       }
  //     });
  //   }
  // });

  constructorBuf.writeln(')');
  final result = constructorBuf.toString() + classBuffer.toString();
  // print(result);
  return result;
}
