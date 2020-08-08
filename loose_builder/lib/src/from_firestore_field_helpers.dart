import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'package:loose/annotations.dart';

import 'package:loose_builder/src/loose_builder_exception.dart';
import 'package:loose_builder/src/recase_helper.dart';

final _checkForLooseDocument = const TypeChecker.fromRuntime(LooseDocument);
final _checkForLooseMap = const TypeChecker.fromRuntime(LooseMap);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);

String convertFromFirestore(FieldElement field, int recase, bool globalNull, [String parent = '', int nested = 0]) {
  
  
  var name = field.name;
  name = recaseFieldName(recase, name);
  var allowNull = globalNull;
  var target = "fields['$name']";

  if (nested > 0) {
    target = parent + target;
  }

  if (_checkForLooseField.hasAnnotationOfExact(field)) {
    final reader = ConstantReader(_checkForLooseField.firstAnnotationOf(field));
    final ignore = reader.peek('ignore')?.boolValue ?? false;
    if (ignore) {
      return '';
    }
    
    if ((reader.peek('ignoreIfNested')?.boolValue ?? false) && nested > 0) {
      return '';
    }
    
    final rename = reader.peek('name')?.stringValue ?? '';
    if (rename.isNotEmpty) {
      name = rename;
    }
    final readNull = reader.peek('readNulls')?.boolValue;
    allowNull = (reader.peek('allowNull')?.boolValue ?? readNull) ?? globalNull;
  }
  

  // final target = "${parent}fields['$name']";
  final assignment = '..$name = ';

  // var nullPrefix = '';
  // if (nullable) {
  //   nullPrefix = "$target.nullValue == null ? null : ";
  // }

  if (_checkForLooseMap.hasAnnotationOfExact(field.type.element) ||
  _checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
    final element = field.type.element;

    if (element is! ClassElement) {
      throw ('LooseMap must only annotate a class.');
    }
    final mapBuf = StringBuffer();
    mapBuf.writeln('$assignment${_looseMapHelper(target, (element as ClassElement), recase, parent: parent, nullable: allowNull, nested: nested)}');
    return mapBuf.toString();
  } else if (field.type.isDartCoreString) {
    return '..$name = ${_stringHelper(target, allowNull)}';
  } else if (field.type.isDartCoreInt) {
    return '..$name = ${_intHelper(target, allowNull)}';
  } else if (field.type.isDartCoreDouble) {
    return '..$name = ${_doubleHelper(target, allowNull)}';
  } else if (field.type.isDartCoreBool) {
    return '..$name = ${_boolHelper(target, allowNull)}';
  } else if (field.type.getDisplayString() == 'DateTime') {
    return '..$name = ${_dateTimeHelper(target, allowNull)}';
  } else if (field.type.isDartCoreList) {
    return '..$name = ${_listHelper(field, target, recase, allowNull)}';
  } else if (field.type.getDisplayString() == 'Reference') {
    return '..$name = ${_referenceHelper(target, allowNull)}';
  } else if (field.type.isDartCoreMap) {
    throw LooseBuilderException('Maps should be implemented as a class annotated with @LooseMap');
  } else {
    throw LooseBuilderException('Getting ${field.type.getDisplayString()} FROM Firestore is not implemented.');
  }


}



String _stringHelper(String target, [bool nullable = false]) {
  final nulls = nullable ? '?' : '';
  return '$target$nulls.stringValue';
}

String _intHelper(String target, [bool nullable = false]) {
  if (nullable) {
    return '$target?.integerValue == null ? null : int.parse($target.integerValue)';
  } else {
    return 'int.parse($target.integerValue)';
  }
}

String _doubleHelper(String target, [bool nullable = false]) {
  final nulls = nullable ? '?' : '';
  return '$target$nulls.doubleValue';
}

String _boolHelper(String target, [bool nullable = false]) {
  final nulls = nullable ? '?' : '';
  return '$target$nulls.booleanValue';
}

String _dateTimeHelper(String target, [bool nullable = false]) {
  if (nullable) {
    return '$target?.timestampValue == null ? null : DateTime.parse($target.timestampValue)';
  } else {
    return 'DateTime.parse($target.timestampValue)';
  }
}

String _referenceHelper(String target, [bool nullable = false]) {
  if (nullable) {
    return '$target?.referenceValue == null ? null : Reference.fromFirestore($target)';
  } else {
    return 'Reference.fromFirestore($target)';
  }
}

String _looseMapHelper(String target, ClassElement element, int recase, {String parent = '', bool nullable = false, int nested = 0}) {
  final buf = StringBuffer();
  if (nullable) {
    buf.write('$target?.mapValue == null ? null : ');
  }
  buf.writeln('(${element.name}()');

    for (final f in element.fields) {
      if (f.isStatic) {
        continue;
      }
      buf.writeln(convertFromFirestore(f, recase, nullable, '$parent$target.mapValue.', nested + 1));
    }
    buf.writeln(')');
    return buf.toString();
}

String _listHelper(FieldElement field, String target, int recase, [bool nullable = false]) {
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
  var buf = StringBuffer();
  if (nullable) {
    buf.write('$target?.arrayValue == null ? null : ');
  }
  // buf.write('List<${types.first.getDisplayString()}>.from(');
  buf.write(target);
  buf.write('.arrayValue.values.map((e) => ');

  if (elementType.isDartCoreString) {
    buf.write("${_stringHelper('e')}");
  } else if (elementType.isDartCoreInt) {
    buf.write("${_intHelper('e')}");
  } else if (elementType.isDartCoreDouble) {
    buf.write("${_doubleHelper('e')}");
  } else if (elementType.isDartCoreBool) {
    buf.write("${_boolHelper('e')}");
  } else if (elementType.getDisplayString() == 'DateTime') {
    buf.write("${_dateTimeHelper('e')}");
  } else if (elementType.getDisplayString() == 'Reference') {
    buf.write("${_referenceHelper('e')}");
  } else if (_checkForLooseMap.hasAnnotationOfExact(elementType.element)
  || _checkForLooseDocument.hasAnnotationOfExact(elementType.element)) {
    buf.write("${_looseMapHelper('e', (elementType.element as ClassElement), recase)}");
  }

  buf.write(').toList()');
  return buf.toString();

}

Iterable<DartType> _getGenericTypes(DartType type) {
  return type is ParameterizedType ? type.typeArguments : const [];
}





