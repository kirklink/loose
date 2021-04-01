import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'from_firestore_field_helpers.dart';
import 'to_firestore_field_helpers.dart';
import 'query_field_helpers.dart';
import 'package:source_gen/source_gen.dart';

import 'package:loose/annotations.dart';
import 'loose_builder_exception.dart';
import 'uses_identifier_helper.dart' show usesIdentifier;
import 'constants.dart' show documentIdFieldName;

final _checkForResource = const TypeChecker.fromRuntime(Resource);
final _checkForLooseField = const TypeChecker.fromRuntime(LooseField);

class LooseDocumentGenerator extends GeneratorForAnnotation<LooseDocument> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw ('LooseDocument must only annotate a class.');
    }

    var $loose = (element as ClassElement).getField('\$loose');
    if ($loose == null || !$loose.isStatic || !$loose.isFinal) {
      var buf = StringBuffer();
      var documentClass = "${element.name}Document";
      buf.writeln(
          '\nThe LooseDocument class "${element.name}" must have a final static field "\$loose".');
      buf.writeln(
          'Add this to ${element.name}: static final \$loose = _\$$documentClass();');
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

    print('getting name');
    var name = annotation.peek('document')?.peek('name')?.stringValue;
    print('getting parent');
    var parent = annotation.peek('document').peek('parent');
    print('getting collection');
    var collection = parent?.peek('name')?.stringValue;

    final path = <String>[];

    print('getting parent again');
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

    classBuf
        .writeln('class $documentName extends DocumentRequest<$className> {');
    classBuf.writeln('@override');
    classBuf.writeln('final Document document;');
    classBuf.writeln('$documentName(this.document);');
    classBuf.writeln(
        'final _\$${className}Fields fields = _\$${className}Fields();');
    classBuf.writeln('@override');
    classBuf.writeln(
        'DocumentResponse<$className> fromFirestore(Map<String, Object> map) {');
    classBuf.writeln("final m = map['fields'] as Map<String, Object>;");

    // fromFields
    classBuf.writeln(
        convertFromFirestore(element, recase, allowNulls, readonlyNulls));

    if (usesIdentifier(element)) {
      classBuf.write(
          "..$documentIdFieldName = (map['name'] as String).split('/').last");
    }
    classBuf.writeln(';');

    // !fromFields
    classBuf.writeln(('return DocumentResponse(e, map);}'));
    classBuf.writeln('@override');
    classBuf.writeln('Map<String, Object> toFirestore($className e) {');
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
