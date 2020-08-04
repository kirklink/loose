import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:loose_builder/src/from_firestore_field_helpers.dart';
import 'package:loose_builder/src/to_firestore_field_helpers.dart';
import 'package:loose_builder/src/query_field_helpers.dart'; 
import 'package:source_gen/source_gen.dart';

import 'package:loose/annotations.dart';
import 'package:loose_builder/src/loose_builder_exception.dart';

final _checkForResource = const TypeChecker.fromRuntime(Resource);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);

class LooseDocumentGenerator extends GeneratorForAnnotation<LooseDocument> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw ('LooseDocument must only annotate a class.');
    }

    var $firestore = (element as ClassElement).getField('\$firestore');
    if ($firestore == null || !$firestore.isStatic || !$firestore.isFinal) {
      var buf = StringBuffer();
      var documentClass = "${element.name}Document";
      buf.writeln(
          '\nThe LooseDocuement class "${element.name}" must have a final static field "\$table".');
      buf.writeln(
          'Add this to ${element.name}: static final \$firestore = _\$$documentClass();');
      throw LooseBuilderException(buf.toString());
    }

    var recase = annotation.peek('useCase')?.objectValue?.getField('none')?.toIntValue() ?? 0;
    recase = annotation.peek('useCase')?.objectValue?.getField('camelCase')?.toIntValue() ?? recase;
    recase = annotation.peek('useCase')?.objectValue?.getField('snakeCase')?.toIntValue() ?? recase;
    recase = annotation.peek('useCase')?.objectValue?.getField('pascalCase')?.toIntValue() ?? recase;
    recase = annotation.peek('useCase')?.objectValue?.getField('kebabCase')?.toIntValue() ?? recase;

    final allowNull = annotation.peek('allowNull')?.boolValue ?? false;

    final useDefaultValues = annotation.peek('useDefaultValues')?.boolValue ?? false;

    if (allowNull && useDefaultValues) {
      throw LooseBuilderException('allowNull and useDefaultValues should not be used together on ${element.name}.');
    }

    
    
    
    var name = annotation.peek('document').peek('name').stringValue;
    // print('name: $name');
    var parent = annotation.peek('document').peek('parent');
    var collection = parent.peek('name').stringValue;

    final path = <String>[];

    parent = parent.peek('parent');

    while (parent != null) {
      path.add(parent.peek('name').stringValue);
      parent = parent.peek('parent');
    }

    final classBuf = StringBuffer();

    final className = '${element.name}';
    final documentName = '_\$${className}Document';

    final qFields = createQueryFields(element, recase);
    
    if (qFields.isNotEmpty) {
      classBuf.writeln(qFields);
      classBuf.writeln('');
    }

    classBuf.writeln('class $documentName extends DocumentShell<$className> implements Documenter<$documentName, $className, _\$${className}Fields> {');
    classBuf.writeln('');
    classBuf.writeln("$documentName([$className entity, String name = '', String createdAt = '', String updatedAt = ''])");
    classBuf.writeln('  : super(entity, name, createdAt, updatedAt);');
    classBuf.writeln('');
    classBuf.writeln('@override');
    classBuf.writeln("final location = DocumentInfo('$name', '$collection', '/${path.reversed.join('/')}');");
    classBuf.writeln('');
    classBuf.writeln('@override');
    classBuf.writeln('final _\$${className}Fields queryFields = _\$${className}Fields();');
    classBuf.writeln('');
    classBuf.writeln('@override');
    classBuf.writeln('$documentName from($className entity) => $documentName(entity);');
    classBuf.writeln('');
    classBuf.writeln('@override');
    classBuf.writeln('$documentName fromFirestore(Map<String, Value> fields, String name, String createTime, String updateTime) {');
    classBuf.write('final e = $className()');
    // fromFields
    final fromFields = StringBuffer();
    for (var field in (element as ClassElement).fields) {
      if (field.isStatic) {
        continue;
      }
      final converted = convertFromFirestore(field, recase, allowNull);
      fromFields.writeln(converted);
      
    }
    fromFields.write(';');
    classBuf.writeln(fromFields);

    // !fromFields
    classBuf.writeln(('return $documentName(e, name, createTime, updateTime);'));
    classBuf.writeln('}');
    classBuf.writeln('@override');
    classBuf.writeln('Map<String, Value> toFirestoreFields() {');
    classBuf.writeln('return {');
    // toFields
    final toFields = StringBuffer();
    for (var field in (element as ClassElement).fields) {
      if (field.isStatic) {
        continue;
      }
      final converted = convertToFirestore(field, recase, allowNull, useDefaultValues);
      if (converted.isNotEmpty) {
        toFields.writeln(converted + ',');
      }
      
    }
    classBuf.writeln(toFields);
    // !toFields
    classBuf.writeln('};');
    classBuf.writeln('}');
    classBuf.writeln('}');
    return classBuf.toString();
  }
}