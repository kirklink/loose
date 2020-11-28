import 'package:analyzer/dart/element/element.dart' show ClassElement;

bool usesIdentifier(ClassElement element) {
  return element.mixins.any((e) {
    return e.getDisplayString(withNullability: false) == 'Identifier' &&
        e.element.location.toString() ==
            'package:loose/src/identifier.dart;package:loose/src/identifier.dart;Identifier';
  });
}
