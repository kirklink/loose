import 'package:loose/src/documenter.dart';
import 'package:loose/src/firestore_database.dart';
import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/constants.dart';

import 'constants.dart';
import 'constants.dart';

class Reference {
  String _location;

  // String get location => _location;

  Reference(Documenter document, FirestoreDatabase database,
      {List<String> idPath = const []}) {
    if (document.location.name == dynamicNameToken && idPath.isEmpty) {
      throw LooseException('A document name must be provided.');
    }
    var name = '';
    if (document.location.name == dynamicNameToken) {
      name = idPath.removeLast();
    }
    var workingPath = '${document.location.path}';
    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;

    if (ancestorCount != idPath.length) {
      throw LooseException(
          '${idPath.length} ancestor ids were provided. $ancestorCount required in $workingPath');
    }

    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }
    _location = '${database.documentRoot}${workingPath}/$name';
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
