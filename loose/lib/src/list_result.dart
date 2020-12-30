import 'package:loose/src/document_shell.dart';
import 'package:loose/src/loose_response.dart';

class ListResults<T extends DocumentShell<S>, S> extends LooseResponse {
  LooseListResponse<T, S> _documents;
  LooseListResponse<T, S> get documents => _documents;
  String _nextPageToken;
  String get nextPageToken => _nextPageToken;

  @override
  int get count => _documents.count;

  ListResults(this._documents, this._nextPageToken) : super();
  ListResults.fail(LooseError error) : super.fail(error);
}
