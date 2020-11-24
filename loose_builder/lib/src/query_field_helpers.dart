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

final _checkForLooseDocument = const TypeChecker.fromRuntime(LooseDocument);
final _checkForLooseMap = const TypeChecker.fromRuntime(LooseMap);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);

String createQueryFields(ClassElement element, int recase,
    {List<String> classParents = const <String>[],
    List<String> fieldParents = const <String>[],
    int nestLevel = 0}) {
  final pageBuf = StringBuffer();

  final classElements = <ClassElement>[];
  classElements.add(element);
  for (final superType in element.allSupertypes) {
    classElements.add(superType.element);
  }

  var className = '${element.name}';
  if (classParents.isNotEmpty) {
    className = "${classParents.join('__')}__$className";
  }

  final privatePrefix = nestLevel == 0 ? '_' : '__';

  final qClassBuf = StringBuffer();
  final qFieldsBuf = StringBuffer();
  qClassBuf.writeln(
      'class ${privatePrefix}\$${className}Fields extends QueryFields {');

  for (final klass in classElements) {
    for (final field in klass.fields) {
      if (field.isStatic || field.isSynthetic) {
        continue;
      }
      if (_checkForLooseMap.hasAnnotationOfExact(field.type.element) ||
          _checkForLooseDocument.hasAnnotationOfExact(field.type.element)) {
        if (field.type.element is! ClassElement) {
          throw ('LooseDocument and LooseMap must only annotate a class: ${field.type.element.getDisplayString(withNullability: false)}');
        }
        // stash.add(field);
        final nextClassParents = <String>[];
        nextClassParents.addAll(classParents);
        nextClassParents.add(element.name);
        final nextFieldParents = <String>[];
        nextFieldParents.addAll(fieldParents);
        nextFieldParents.add(field.name);
        final nextPage = createQueryFields(field.type.element, recase,
            classParents: nextClassParents,
            fieldParents: nextFieldParents,
            nestLevel: nestLevel + 1);
        if (nextPage.isNotEmpty) {
          final childClass = field.type.element.name;
          qFieldsBuf.writeln(
              'final ${field.name} = __\$${className}__${childClass}Fields();');
          pageBuf.writeln(nextPage);
        }
      } else {
        final queryField = convertToQueryField(field, recase, fieldParents);
        if (queryField.isNotEmpty) {
          qFieldsBuf.writeln(queryField);
        }
      }
      if (qFieldsBuf.isEmpty && nestLevel != 0) {
        return '';
      }
    }
  }

  if (qFieldsBuf.isEmpty && nestLevel != 0) {
    return '';
  }
  qClassBuf.writeln(qFieldsBuf);
  qClassBuf.writeln('}');
  pageBuf.writeln(qClassBuf);

  // print(pageBuf);
  return pageBuf.toString();
}

String convertToQueryField(FieldElement field, int recase,
    [List<String> fieldParents = const <String>[]]) {
  var fieldName = field.name;
  var dbName = recaseFieldName(recase, field.name);
  if (fieldParents.isNotEmpty) {
    // fieldName = '${parents.join('.')}.${field.name}';
    final parentsString =
        fieldParents.map((e) => recaseFieldName(recase, e)).toList().join('.');
    final dbFieldName = recaseFieldName(recase, field.name);
    dbName = '$parentsString.$dbFieldName';
    // dbName = '{$parents.map((e) => recaseFieldName(recase, e)).join(".")}.${recaseFieldName(recase, field.name)}';
  }

  if (_checkForLooseField.hasAnnotationOfExact(field)) {
    final reader = ConstantReader(_checkForLooseField.firstAnnotationOf(field));
    final canQuery = reader.peek('canQuery')?.boolValue ?? true;
    if (!canQuery) {
      return '';
    }
    final rename = reader.peek('name')?.stringValue ?? '';
    if (rename.isNotEmpty) {
      final parentsString = fieldParents
          .map((e) => recaseFieldName(recase, e))
          .toList()
          .join('.');
      dbName = '$parentsString.$rename';
    }
    // } else {
    //   return '';
  }

  if (field.type.isDartCoreString) {
    return "final $fieldName = StringField('$dbName');";
  } else if (field.type.isDartCoreInt) {
    return "final $fieldName = IntegerField('$dbName');";
  } else if (field.type.isDartCoreDouble) {
    return "final $fieldName = DoubleField('$dbName');";
  } else if (field.type.isDartCoreBool) {
    return "final $fieldName = BoolField('$dbName');";
  } else if (field.type.getDisplayString(withNullability: false) ==
      'DateTime') {
    return "final $fieldName = DateTimeField('$dbName');";
  } else if (field.type.getDisplayString(withNullability: false) ==
      'Reference') {
    return "final $fieldName = ReferenceField('$dbName');";

    // LIST
  } else if (field.type.isDartCoreList) {
    final types = _getGenericTypes(field.type);
    if (types.isEmpty) {
      throw LooseBuilderException(
          'The element type of ${field.name} should be specified.');
    }
    if (types.first.isDartCoreList) {
      throw LooseBuilderException(
          'Cannot nest a list within the list ${field.name}.');
    }
    if (types.first.isDartCoreMap) {
      throw LooseBuilderException(
          'Maps within the list ${field.name} must be implemented by using a class annotated with @LooseMap');
    }
    final elementType = types.first;
    var buf = StringBuffer();
    buf.write("final $fieldName = ArrayField('$dbName', ");
    if (elementType.isDartCoreString) {
      buf.write("(String e) => {'stringValue': e}");
    } else if (elementType.isDartCoreInt) {
      buf.write("(int e) => {'integerValue': e.toString()}");
    } else if (elementType.isDartCoreDouble) {
      buf.write("(double e) => {'doubleValue': e}");
    } else if (elementType.isDartCoreBool) {
      buf.write("(bool e) => {'booleanValue': e}");
    } else if (elementType.getDisplayString(withNullability: false) ==
        'DateTime') {
      buf.write("(DateTime e) => {'timestampValue': e.toIso8601String()}");
    } else if (elementType.getDisplayString(withNullability: false) ==
        'Reference') {
      buf.write("(Reference e) => {'referenceValue': e.toString()}");
    } else {
      return '';
    }
    buf.write(");");
    return buf.toString();
  } else if (_checkForLooseDocument.hasAnnotationOfExact(field.type.element) ||
      _checkForLooseMap.hasAnnotationOfExact(field.type.element)) {
    final element = field.type.element;
    if (element is! ClassElement) {
      throw ('LooseMap must only annotate a class: ${field.type.getDisplayString(withNullability: false)}');
    }
    final buf = StringBuffer();
    for (final f in (element as ClassElement).fields) {
      if (f.isStatic) {
        continue;
      }
      var nextParents = <String>[]
        ..addAll(fieldParents)
        ..add(field.name);
      buf.write(convertToQueryField(f, recase, nextParents));
    }
    return buf.toString();
  }
  return '';
}

Iterable<DartType> _getGenericTypes(DartType type) {
  return type is ParameterizedType ? type.typeArguments : const [];
}
