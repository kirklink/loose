import 'package:loose/annotations.dart';

import 'loose_exception.dart';
import 'document_request.dart';
import 'constants.dart';

class BatchGetRequest<T> {
  final _documents = <String, DocumentRequest<T>>{};
  Map<String, DocumentRequest<T>> get documents => Map.unmodifiable(_documents);

  void add(DocumentRequest<T> request, {List<String> idPath = const []}) {
    final tokenCount =
        dynamicNameToken.allMatches(request.document.path).length;
    if (tokenCount != idPath.length) {
      throw LooseException(
          '${idPath.length} ids provided and $tokenCount are required.');
    }
    var workingPath = request.document.path;
    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }
    _documents.putIfAbsent(workingPath, () => request);
    return;
  }
}
