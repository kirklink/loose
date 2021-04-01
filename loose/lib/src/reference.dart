import 'package:loose/src/document_request.dart';

import 'document_request.dart';
import 'firestore_database.dart';
import 'loose_exception.dart';
import 'constants.dart';

class Reference {
  String _location;

  String get name => _location;

  Reference(DocumentRequest request, FirestoreDatabase database,
      {List<String> idPath = const []}) {
    final tokenCount =
        dynamicNameToken.allMatches(request.document.path).length;
    if (tokenCount != idPath.length) {
      throw LooseException(
          '${idPath.length} ids provided and $tokenCount are required.');
    }
    var workingPath = '${request.document.path}';

    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }
    _location = '${database.documentRoot}${workingPath}';
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
