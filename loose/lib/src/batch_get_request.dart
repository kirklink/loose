import 'package:loose/annotations.dart';

import 'loose_exception.dart';
import 'document_request.dart';
import 'constants.dart';

class BatchGetRequest<T> {
  final _documents = <String, DocumentRequest<T>>{};
  Map<String, DocumentRequest<T>> get documents => Map.unmodifiable(_documents);

  void add(DocumentRequest<T> request, {List<String> idPath = const []}) {
    final workingPath = request.document.resolvePath(idPath);
    _documents.putIfAbsent(workingPath, () => request);
    return;
  }
}
