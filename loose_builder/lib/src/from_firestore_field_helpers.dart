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

String convertFromFirestore(ClassElement clazz, int recase, bool globalAllowNull, [String parent = '', int nestLevel = 0]) {
  
  final classBuffer = StringBuffer();
  
  for (final field in clazz.fields) {

    var name = field.name;
    name = recaseFieldName(recase, name);
    var allowNull = globalAllowNull;

    if (_checkForLooseField.hasAnnotationOfExact(field)) {
      final reader = ConstantReader(_checkForLooseField.firstAnnotationOf(field));
      
      final ignore = reader.peek('ignore')?.boolValue ?? false;
      if (ignore) {
        continue;
      }
      
      if ((reader.peek('ignoreIfNested')?.boolValue ?? false) && nestLevel > 0) {
        continue;
      }
      
      final rename = reader.peek('name')?.stringValue ?? '';
      if (rename.isNotEmpty) {
        name = rename;
      }
      final readNull = reader.peek('readNulls')?.boolValue;
      allowNull = (reader.peek('allowNull')?.boolValue ?? readNull) ?? globalAllowNull;
    }

    if (field.type.isDartCoreString) {
      classBuffer.writeln("..${field.name} = FromFs.string(m['${field.name}'])");
    } else if (field.type.isDartCoreInt) {
      classBuffer.writeln("..${field.name} = FromFs.integer(m['${field.name}'])");
    } else if (field.type.isDartCoreDouble) {
      classBuffer.writeln("..${field.name} = FromFs.float(m['${field.name}'])");
    } else if (field.type.isDartCoreBool) {
      classBuffer.writeln("..${field.name} = FromFs.boolean(m['${field.name}'])");
    } else if (field.type.getDisplayString() == 'DateTime') {
      classBuffer.writeln("..${field.name} = FromFs.datetime(m['${field.name}'])");
    } else if (field.type.getDisplayString() == 'Reference') {
      classBuffer.writeln("..${field.name} = FromFs.reference(m['${field.name}'])");
    
    // Map
    } else if (_checkForLooseMap.hasAnnotationOfExact(field.type.element)
    || _checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
      if (field.type.element is! ClassElement) {
        throw LooseBuilderException('LooseDocument or LooseMap must only annotate classes. Field "${field.name}" is not a class.');
      }
      final mapBuf = StringBuffer();
      mapBuf.writeln("..${field.name} = FromFs.map(m['${field.name}'], (m) => ${field.type.getDisplayString()}()");
      mapBuf.writeln('${convertFromFirestore(field.type.element, recase, globalAllowNull)}');
      mapBuf.writeln(')');
      classBuffer.write(mapBuf.toString());
    
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
      listBuf.write("..${field.name} = FromFs.list(m['${field.name}'], ");
      if (elementType.isDartCoreString) {
        listBuf.write('(e) => FromFs.string(e)');
      } else if (elementType.isDartCoreInt) {
        listBuf.write('(e) => FromFs.integer(e)');
      } else if (elementType.isDartCoreDouble) {
        listBuf.write('(e) => FromFs.float(e)');
      } else if (elementType.isDartCoreBool) {
        listBuf.write('(e) => FromFs.boolean(e)');
      } else if (elementType.getDisplayString() == 'DateTime') {
        listBuf.write('(e) => FromFs.datetime(e)');
      } else if (elementType.getDisplayString() == 'Reference') {
        listBuf.write('(e) => FromFs.reference(e)');
      } else if (_checkForLooseMap.hasAnnotationOfExact(elementType.element)
        || _checkForLooseDocument.hasAnnotationOfExact(elementType.element)) {
        if (elementType.element is! ClassElement) {
          throw LooseBuilderException('LooseDocument or LooseMap must only annotate classes. Field "${field.name}" is not a class.');
        }

        listBuf.write("(e) => FromFs.map(e, (m) => ${elementType.getDisplayString()}()");
        listBuf.writeln('${convertFromFirestore(elementType.element, recase, globalAllowNull)}');
        listBuf.write(')');
      }
      listBuf.writeln(')');
      classBuffer.writeln(listBuf.toString());
    }
  }
  // print(classBuffer);
  return classBuffer.toString();
}