import 'document.dart';
import 'firestore_database.dart';
import 'loose_exception.dart';
import 'constants.dart';

class Reference {
  String _location;

  // String get location => _location;

  Reference(Document document, FirestoreDatabase database,
      {List<String> idPath = const []}) {
    if (document.id == dynamicNameToken && idPath.isEmpty) {
      throw LooseException('A document name must be provided.');
    }
    var name = '';
    if (document.id == dynamicNameToken) {
      name = idPath.removeLast();
    }
    var workingPath = '${document.path}';
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
  bool operator ==(covariant Reference other) {
    return _location == other._location;
  }

  @override
  int get hashCode => _location.hashCode;

  Reference.fromFirestore(Map<String, Object> value) {
    _location = value['referenceValue'] as String;
  }
}
