import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'package:loose/annotations.dart';

import 'package:loose_builder/src/loose_builder_exception.dart';
import 'package:loose_builder/src/recase_helper.dart';

final _checkForLooseDocument = const TypeChecker.fromRuntime(LooseDocument);
final _checkForLooseMap = const TypeChecker.fromRuntime(LooseMap);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);

Iterable<DartType> _getGenericTypes(DartType type) {
  return type is ParameterizedType ? type.typeArguments : const [];
}

String convertToFirestore(ClassElement clazz, int recase, bool globalAllowNull, bool globalUseDefaultValues, {String parent = '', int nestLevel = 0}) {

  final classBuffer = StringBuffer();
  classBuffer.writeln('{');

  for (final field in clazz.fields) {
    if (field.isStatic) {
      continue;
    }
    var name = field.name;
    name = recaseFieldName(recase, name);
    var allowNull = globalAllowNull;
    var useDefaultValue = globalUseDefaultValues;

    if (_checkForLooseField.hasAnnotationOfExact(field)) {
      final reader = ConstantReader(_checkForLooseField.firstAnnotationOf(field));
    
      final ignore = reader.peek('ignore')?.boolValue ?? false;
      if (ignore) {
        continue;
      }
    
      final readOnly = reader.peek('readOnly')?.boolValue ?? false;
      if (readOnly) {
        continue;
      }

      if ((reader.peek('ignoreIfNested')?.boolValue ?? false) && nestLevel > 0) {
        continue;
      }

      final rename = reader.peek('name')?.stringValue ?? '';
      if (rename.isNotEmpty) {
        name = rename;
      }
      
      if ((reader.peek('allowNull')?.boolValue ?? false) && (reader.peek('useDefaultValue')?.boolValue ?? false)) {
        throw LooseBuilderException('allowNull and useDefaultValue should not be used together on LooseField ${field.name}.');
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

    var inheritedName = name;
    if (parent.isNotEmpty) {
      inheritedName = '$parent?.$name';
    }
    
    String mode = '';
    if (useDefaultValue) {
      mode = ', useDefaultValue: true';
    } else if (allowNull) {
      mode = ', allowNull: true';
    }
    if (field.type.isDartCoreString) {
      classBuffer.writeln("...{'$name' : ToFs.string(e?.$inheritedName$mode)},");
    } else if (field.type.isDartCoreInt) {
      classBuffer.writeln("...{'$name' : ToFs.integer(e?.$inheritedName$mode)},");
    } else if (field.type.isDartCoreDouble) {
      classBuffer.writeln("...{'$name' : ToFs.float(e?.$inheritedName$mode)},");
    } else if (field.type.isDartCoreBool) {
      classBuffer.writeln("...{'$name' : ToFs.boolean(e?.$inheritedName$mode)},");
    } else if (field.type.getDisplayString() == 'DateTime') {
      classBuffer.writeln("...{'$name' : ToFs.datetime(e?.$inheritedName$mode)},");
    } else if (field.type.getDisplayString() == 'Reference') {
      classBuffer.writeln("...{'$name' : ToFs.reference(e?.$inheritedName$mode)},");
    // Class
    } else if (_checkForLooseMap.hasAnnotationOfExact(field.type.element)
      || _checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
      if (field.type.element is! ClassElement) {
        throw LooseBuilderException('LooseDocument or LooseMap must only annotate classes. Field "${field.name}" is not a class.');
      }
      if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
        nestLevel = nestLevel + 1;
      }
      classBuffer.write("...{'$name' : ToFs.map(${convertToFirestore(field.type.element, recase, globalAllowNull, globalUseDefaultValues, parent: inheritedName, nestLevel: nestLevel)}$mode)},");
    // List
    } else if (field.type.isDartCoreList) {
      final elementTypes = _getGenericTypes(field.type);
      if (elementTypes.isEmpty) {
        throw LooseBuilderException('The element type of ${field.name} should be specified.');
      }
      if (elementTypes.first.isDartCoreList) {
        throw LooseBuilderException('Cannot nest a list within the list ${field.name}.');
      }
      if (elementTypes.first.isDartCoreMap) {
        throw LooseBuilderException('Maps within the list ${field.name} must be implemented by using a class annotated with @LooseMap');
      }
      final elementType = elementTypes.first;
      final listBuf = StringBuffer();
      listBuf.write("...{'$name' : ToFs.list(e?.$inheritedName?.map((e) => ");
      if (elementType.isDartCoreString) {
        listBuf.write('ToFs.string(e)');
      } else if (elementType.isDartCoreInt) {
        listBuf.write('ToFs.integer(e)');
      } else if (elementType.isDartCoreDouble) {
        listBuf.write('ToFs.float(e)');
      } else if (elementType.isDartCoreBool) {
        listBuf.write('ToFs.boolean(e)');
      } else if (elementType.getDisplayString() == 'DateTime') {
        listBuf.write('ToFs.datetime(e)');
      } else if (elementType.getDisplayString() == 'Reference') {
        listBuf.write('ToFs.reference(e)');
      } else if (_checkForLooseMap.hasAnnotationOfExact(elementType.element)
      || _checkForLooseDocument.hasAnnotationOfExact(elementType.element)) {
      if (elementType.element is! ClassElement) {
        throw LooseBuilderException('LooseDocument or LooseMap must only annotate classes. Field elements "${elementType.getDisplayString()}" are not user defined classes.');
      }
        listBuf.write("ToFs.map(${convertToFirestore(elementType.element, recase, globalAllowNull, globalUseDefaultValues)}$mode)");
      }
      listBuf.write(")?.toList()$mode)},");
      classBuffer.writeln(listBuf.toString());
    
    }
  }
  classBuffer.writeln('}');
  // print(classBuffer);
  return classBuffer.toString();
}