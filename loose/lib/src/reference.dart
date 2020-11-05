import 'package:loose/src/documenter.dart';
import 'package:loose/src/firestore_database.dart';
import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/constants.dart';

class Reference {
  String _location;

  // String get location => _location;

  Reference(Documenter document, FirestoreDatabase database,
      [String name = '']) {
    if (document.location.name == dynamicNameToken && name.isEmpty) {
      throw LooseException('A document name must be provided.');
    }
    if (document.location.name != dynamicNameToken) {
      name = document.location.name;
    }
    _location = '${database.documentRoot}${document.location.path}/$name';
  }

  @override
  String toString() {
    return _location;
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! Reference) {
      return false;
    }
    return toString() == other.toString();
  }

  Reference.fromFirestore(Map<String, Object> value) {
    _location = value['referenceValue'] as String;
  }
}
