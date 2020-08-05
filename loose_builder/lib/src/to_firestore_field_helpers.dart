import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'package:loose/annotations.dart';

import 'package:loose_builder/src/loose_builder_exception.dart';
import 'package:loose_builder/src/recase_helper.dart';

final _checkForLooseDocument = const TypeChecker.fromRuntime(LooseDocument);
final _checkForLooseMap = const TypeChecker.fromRuntime(LooseMap);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);

String convertToFirestore(FieldElement field, int recase, bool globalNull, bool globaelUseDefaultValues, [String parent = '', int nested = 0, bool isList = false]) {

  var name = field.name;

  name = recaseFieldName(recase, name);
  var nullable = globalNull;
  var useDefaultValues = globaelUseDefaultValues;

  if (_checkForLooseField.hasAnnotationOfExact(field)) {
    final reader = ConstantReader(_checkForLooseField.firstAnnotationOf(field));
    final ignore = reader.peek('ignore')?.boolValue ?? false;
    if (ignore) {
      return '';
    }
    final readOnly = reader.peek('readOnly')?.boolValue ?? false;
    if (readOnly) {
      return '';
    }
    final rename = reader.peek('name')?.stringValue ?? '';
    if (rename.isNotEmpty) {
      name = rename;
    }
    
    if (reader.peek('allowNull')?.boolValue == true && reader.peek('useDefaultValue')?.boolValue == true) {
      throw LooseBuilderException('allowNull and useDefaultValue should not be used together on LooseField ${field.name}.');
    }

    if (reader.peek('allowNull')?.boolValue == true) {
      nullable = true;
      useDefaultValues = false;
    }

    if (reader.peek('useDefaultValue')?.boolValue == true) {
      nullable = false;
      useDefaultValues = true;
    }
    

  }
  
  final inheritedName = '${parent}$name';
  final fullName = nested > 1 || isList ? 'e.$inheritedName' : 'entity.$inheritedName';

  
  
  var nullPrefix = '';
  var nullSuffix = '';
  if (nullable) {
    nullPrefix = "$fullName == null ? (Value()..nullValue = 'NULL_VALUE') : (";
    nullSuffix = ')';
  }

  
  // LooseMap
  if (_checkForLooseMap.hasAnnotationOfExact(field.type.element) ||
  _checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
    final element = field.type.element;
    if (element is! ClassElement) {
      throw ('LooseDocument and LooseMap must only annotate a class: ${field.type.getDisplayString()}');
    }
    var defaultPrefix = '';
    var defaultSuffix = '';


    
    final buf = StringBuffer();
    buf.writeln("'$name' : ${defaultPrefix}${nullPrefix}Value()..mapValue = (MapValue()..fields = {");
    for (final f in (element as ClassElement).fields) {
      if (f.isStatic) {
        continue;
      }
      var defaultValueCheck = '';
      if (useDefaultValues) {
        defaultValueCheck = '?';
      }
      // reset the nest level 
      final nestLevel = _checkForLooseDocument.hasAnnotationOfExact(element) ? 0 : nested + 1;
      buf.write(convertToFirestore(f, recase, nullable, useDefaultValues, '${inheritedName}${defaultValueCheck}.', nestLevel));
      buf.writeln(',');
    }
    buf.writeln('})${nullSuffix}${defaultSuffix}');
    return buf.toString();
  // String
  } else if (field.type.isDartCoreString) {
    if (useDefaultValues) {
      return "'$name': Value()..stringValue = $fullName ?? ''"; 
    } else {
      return "'$name': ${nullPrefix}Value()..stringValue = $fullName${nullSuffix}";
    }
  // int
  } else if (field.type.isDartCoreInt) {
    if (useDefaultValues) {
      return "'$name': Value()..integerValue = $fullName?.toString() ?? '0'";  
    } else {
      return "'$name': ${nullPrefix}Value()..integerValue = $fullName.toString()${nullSuffix}";
    }
  // double
  } else if (field.type.isDartCoreDouble) {
    if (useDefaultValues) {
      return "'$name': Value()..doubleValue = $fullName ?? 0.0";  
    } else {
      return "'$name': ${nullPrefix}Value()..doubleValue = $fullName${nullSuffix}";
    }
  // bool
  } else if (field.type.isDartCoreBool) {
    if (useDefaultValues) {
      return "'$name': Value()..booleanValue = $fullName ?? false";  
    } else {
      return "'$name': ${nullPrefix}Value()..booleanValue = $fullName${nullSuffix}";
    }
  // DateTime
  } else if (field.type.getDisplayString() == 'DateTime') {
    if (useDefaultValues) {
      return "'$name': Value()..timestampValue = $fullName?.toIso8601String() ?? '0000-01-01T00:00:00.000'";  
    } else {
      return "'$name': ${nullPrefix}Value()..timestampValue = $fullName.toIso8601String()${nullSuffix}";
    }
  // Reference
  } else if (field.type.getDisplayString() == 'Reference') {
    if (useDefaultValues) {
      return "'$name': Value()..referenceValue = $fullName?.toString() ?? ''";  
    } else {
      return "'$name': ${nullPrefix}Value()..referenceValue = $fullName.toString()${nullSuffix}";
    }
  // List
  } else if (field.type.isDartCoreList) {
    final types = _getGenericTypes(field.type);
    if (types.isEmpty) {
      throw LooseBuilderException('The element type of ${field.name} should be specified.');
    }
    if (types.first.isDartCoreList) {
      throw LooseBuilderException('Cannot nest a list within the list ${field.name}.');
    }
    if (types.first.isDartCoreMap) {
      throw LooseBuilderException('Maps within the list ${field.name} must be implemented by using a class annotated with @LooseMap');
    }
    final elementType = types.first;
      var defaultPrefix = '';
      var defaultSuffix = '';
    final listParent = nested > 0 ? 'e' : 'entity';
    if (useDefaultValues) {
      defaultPrefix = '$listParent.$inheritedName == null ? (Value()..arrayValue = (ArrayValue()..values = const [])) : (';
      defaultSuffix = ')';
    }
    var buf = StringBuffer();
    buf.write("'$name': ${defaultPrefix}${nullPrefix}Value()..arrayValue = (ArrayValue()..values = $listParent.$inheritedName.map((e) => Value()..");
    if (elementType.isDartCoreString) {
      buf.write('stringValue = e');
    } else if (elementType.isDartCoreInt) {
      buf.write('integerValue = e.toString()');
    } else if (elementType.isDartCoreDouble) {
      buf.write('doubleValue = e');
    } else if (elementType.isDartCoreBool) {
      buf.write('booleanValue = e');
    } else if (elementType.getDisplayString() == 'DateTime') {
      buf.write('timestampValue = e.toIso8601String()');
    } else if (elementType.getDisplayString() == 'Reference') {
      buf.write('referenceValue = e.toString()');
    } else if (_checkForLooseMap.hasAnnotationOfExact(elementType.element) ||
    _checkForLooseDocument.hasAnnotationOfExact(elementType.element)) {
      buf.write('mapValue = (MapValue()..fields = {');
      for (final f in (elementType.element as ClassElement).fields) {
        if (f.isStatic) {
          continue;
        }
        buf.write(convertToFirestore(f, recase, nullable, useDefaultValues, '', nested + 1, true));
        buf.writeln(',');
      }
      buf.writeln('})');
      }

    buf.write(').toList())${nullSuffix}${defaultSuffix}');
    return buf.toString();


  } else if (field.type.isDartCoreMap) {
    throw LooseBuilderException('Maps should be implemented as a class annotated with @LooseMap');
  } else {
    throw LooseBuilderException('Sending type ${field.type.getDisplayString()} TO Firestore is not implemented.');
  }


  

}

Iterable<DartType> _getGenericTypes(DartType type) {
  return type is ParameterizedType ? type.typeArguments : const [];
}
