import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:loose_builder/src/from_firestore_field_helpers.dart';
import 'package:loose_builder/src/to_firestore_field_helpers.dart';
import 'package:loose_builder/src/query_field_helpers.dart';
import 'package:source_gen/source_gen.dart';

import 'package:loose/annotations.dart';
import 'package:loose_builder/src/loose_builder_exception.dart';
import 'package:loose_builder/src/uses_identifier_helper.dart'
    show usesIdentifier;
import 'package:loose_builder/src/constants.dart' show documentIdFieldName;

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
          '\nThe LooseDocuement class "${element.name}" must have a final static field "\$firestore".');
      buf.writeln(
          'Add this to ${element.name}: static final \$firestore = _\$$documentClass();');
      throw LooseBuilderException(buf.toString());
    }

    var recase = annotation
            .peek('useCase')
            ?.objectValue
            ?.getField('none')
            ?.toIntValue() ??
        0;
    recase = annotation
            .peek('useCase')
            ?.objectValue
            ?.getField('camelCase')
            ?.toIntValue() ??
        recase;
    recase = annotation
            .peek('useCase')
            ?.objectValue
            ?.getField('snakeCase')
            ?.toIntValue() ??
        recase;
    recase = annotation
            .peek('useCase')
            ?.objectValue
            ?.getField('pascalCase')
            ?.toIntValue() ??
        recase;
    recase = annotation
            .peek('useCase')
            ?.objectValue
            ?.getField('kebabCase')
            ?.toIntValue() ??
        recase;

    final allowNulls = annotation.peek('allowNulls')?.boolValue ?? false;

    final useDefaultValues =
        annotation.peek('useDefaultValues')?.boolValue ?? false;

    final readonlyNulls = annotation.peek('readonlyNulls')?.boolValue ?? false;

    if (allowNulls && useDefaultValues) {
      throw LooseBuilderException(
          'allowNull and useDefaultValues should not be used together on ${element.name}.');
    }

    final suppressWarnings =
        annotation.peek('suppressWarning')?.boolValue ?? false;

    var name = annotation.peek('document').peek('name').stringValue;
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

    final qFields = createDocumentFields(element, recase);

    if (qFields.isNotEmpty) {
      classBuf.writeln(qFields);
      classBuf.writeln('');
    }

    classBuf.writeln(
        'class $documentName extends DocumentShell<$className> implements Documenter<$documentName, $className, _\$${className}Fields> {');
    classBuf.writeln('');
    classBuf.writeln(
        "$documentName([$className entity, String name = '', String createdAt = '', String updatedAt = ''])");
    classBuf.writeln('  : super(entity, name, createdAt, updatedAt);');
    classBuf.writeln('');
    classBuf.writeln('@override');
    classBuf.writeln(
        "final location = DocumentInfo('$name', '$collection', '/${path.reversed.join('/')}');");
    classBuf.writeln('');
    classBuf.writeln('@override');
    classBuf.writeln(
        'final _\$${className}Fields fields = _\$${className}Fields();');
    classBuf.writeln('');
    classBuf.writeln('@override');
    classBuf.writeln(
        '$documentName from($className entity) => $documentName(entity);');
    classBuf.writeln('');
    classBuf.writeln('@override');
    classBuf.writeln(
        '$documentName fromFirestore(Map<String, Object> m, String name, String createTime, String updateTime) {');

    // fromFields
    classBuf.writeln(
        convertFromFirestore(element, recase, allowNulls, readonlyNulls));

    if (usesIdentifier(element)) {
      classBuf.write("..$documentIdFieldName = name.split('/').last");
    }
    classBuf.writeln(';');

    // !fromFields
    classBuf
        .writeln(('return $documentName(e, name, createTime, updateTime);'));
    classBuf.writeln('}');
    classBuf.writeln('');
    classBuf.writeln('@override');
    classBuf.writeln('Map<String, Object> toFirestoreFields() {');
    classBuf.writeln('final e = entity;');
    classBuf.write("return {'fields': ");
    // toFields
    final converted = convertToFirestore(
        element, recase, allowNulls, useDefaultValues, suppressWarnings);
    classBuf.writeln(converted);
    classBuf.writeln('};}');
    // !toFields
    classBuf.writeln('}');
    return classBuf.toString();
  }
}
