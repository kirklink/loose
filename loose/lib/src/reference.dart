import 'package:googleapis/firestore/v1.dart' as fs;

import 'package:loose/src/documenter.dart';
import 'package:loose/src/firestore_database.dart';
import 'package:loose/src/loose_exception.dart';

class Reference {
  String _location;

  // String get location => _location;
  
  Reference(Documenter document, FirestoreDatabase database, [String name = '']) {
    if (document.location.name == '@' && name.isEmpty) {
      throw LooseException('A document name must be provided.');
    }
    if (document.location.name != '@') {
      name = document.location.name;
    }
    _location = '${database.rootPath}/${document.location.path}/$name';
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
  
  Reference.fromFirestore(fs.Value value) {
    _location = value.referenceValue;
  }

  
  

}


