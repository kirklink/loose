// class _$TestFields extends QueryFields {
//   final test_text = StringField('test_text');
//   final test_int = IntegerField('test_int');
// }

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'package:loose_builder/src/recase_helper.dart';
import 'package:loose_builder/src/loose_builder_exception.dart';
import 'package:loose/annotations.dart';

final _checkForLooseMap = const TypeChecker.fromRuntime(LooseMap);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);


String createQueryFields(Element element, int recase, [
  List<String> classParents = const <String>[],
  List<String> fieldParents = const <String>[]
  ]) {
  // QueryFields
    
    var className = '${element.name}';
    if (classParents.isNotEmpty) {
      className = "${classParents.join('__')}__$className";
    }
    final qFieldsBuf = StringBuffer();
    qFieldsBuf.writeln('class _\$${className}Fields extends QueryFields {');
    
    final stash = <FieldElement>[];
    
    for (final field in (element as ClassElement).fields) {
      if (field.isStatic) {
        continue;
      }
      if (_checkForLooseMap.hasAnnotationOfExact(field.type.element)) {
        if (field.type.element is! ClassElement) {
          throw ('LooseMap must only annotate a class: ${field.type.element.getDisplayString(withNullability: null)}');
        }
        stash.add(field);
        final childClass = field.type.element.name;
        qFieldsBuf.writeln('final ${field.name} = _\$${className}__${childClass}Fields();');
        continue;
      }
      final queryField = convertToQueryField(field, recase, fieldParents);
      if (queryField.isNotEmpty) {
        qFieldsBuf.writeln(queryField);  
      }
    }
    qFieldsBuf.writeln('}');
    for (final field in stash) {
      final nextClassParents = <String>[];
      nextClassParents.addAll(classParents);
      nextClassParents.add(element.name);
      final nextFieldParents = <String>[];
      nextFieldParents.addAll(fieldParents);
      nextFieldParents.add(field.name);
      qFieldsBuf.writeln(createQueryFields(field.type.element, recase, nextClassParents, nextFieldParents));
      
    }
    return qFieldsBuf.toString();

}


String convertToQueryField(FieldElement field, int recase, [List<String> fieldParents = const <String>[]]) {

  var fieldName = field.name;
  var dbName = recaseFieldName(recase, field.name);
  if (fieldParents.isNotEmpty) {
    // fieldName = '${parents.join('.')}.${field.name}';
    final parentsString = fieldParents.map((e) => recaseFieldName(recase, e)).toList().join('.');
    final dbFieldName = recaseFieldName(recase, field.name);
    dbName = '$parentsString.$dbFieldName';
    // dbName = '{$parents.map((e) => recaseFieldName(recase, e)).join(".")}.${recaseFieldName(recase, field.name)}';
  }
  
  if (_checkForLooseField.hasAnnotationOfExact(field)) {
    final reader = ConstantReader(_checkForLooseField.firstAnnotationOf(field));
    final canQuery = reader.peek('canQuery')?.boolValue ?? false;
    if (!canQuery) {
      return '';
    }
    final rename = reader.peek('name')?.stringValue ?? '';
    if (rename.isNotEmpty) {
      dbName = rename;
    }
  } else {
    return '';
  }


  if (field.type.isDartCoreString) {
    return "final $fieldName = StringField('$dbName');";
  } else if (field.type.isDartCoreInt) {
    return "final $fieldName = IntegerField('$dbName');";
  } else if (field.type.isDartCoreDouble) {
    return "final $fieldName = DoubleField('$dbName');";
  } else if (field.type.isDartCoreBool) {
    return "final $fieldName = BoolField('$dbName');";
  } else if (field.type.getDisplayString() == 'DateTime') {
    return "final $fieldName = DateTimeField('$dbName');";
  } else if (field.type.getDisplayString() == 'Reference') {
    return "final $fieldName = ReferenceField('$dbName');";
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
    var buf = StringBuffer();
    buf.write("final $fieldName = ArrayField('$dbName', ");
    if (elementType.isDartCoreString) {
      buf.write('(String e) => Value()..stringValue = e');
    } else if (elementType.isDartCoreInt) {
      buf.write('(int e) => Value()..integerValue = e.toString()');
    } else if (elementType.isDartCoreDouble) {
      buf.write('(double e) => Value()..doubleValue = e');
    } else if (elementType.isDartCoreBool) {
      buf.write('(bool e) => Value()..booleanValue = e');
    } else if (elementType.getDisplayString() == 'DateTime') {
      buf.write('(DateTime e) => Value()..timestampValue = e.toIso8601String()');
    } else if (elementType.getDisplayString() == 'Reference') {
      buf.write('(Reference e) => Value()..referenceValue = e.toString()');
    }
    buf.write(");");
    return buf.toString();

  // } else if (_checkForLooseMap.hasAnnotationOfExact(field.type.element)) {
  //   final element = field.type.element;
  //   if (element is! ClassElement) {
  //     throw ('LooseMap must only annotate a class: ${field.type.getDisplayString()}');
  //   }
  //   final buf = StringBuffer();
  //   for (final f in (element as ClassElement).fields) {
  //     if (f.isStatic) {
  //       continue;
  //     }
  //     var nextParents = <String>[]..addAll(parents)..add(field.name);
  //     buf.write(convertToQueryField(f, recase, nextParents));
  //   }
  //   return buf.toString();
  }
  return '';




}

Iterable<DartType> _getGenericTypes(DartType type) {
  return type is ParameterizedType ? type.typeArguments : const [];
}
