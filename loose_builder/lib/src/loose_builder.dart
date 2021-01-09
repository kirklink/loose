import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'loose_entity_generator.dart';

Builder LooseBuilder(BuilderOptions options) =>
    SharedPartBuilder([LooseDocumentGenerator()], 'loose_builder');
