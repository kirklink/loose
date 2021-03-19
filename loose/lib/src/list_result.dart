import 'document_response.dart';
import 'loose_response.dart';

class ListResults<DocumentResponse> extends LooseResponse {
  LooseListResponse<DocumentResponse> _documents;
  LooseListResponse<DocumentResponse> get documents => _documents;
  String _nextPageToken;
  String get nextPageToken => _nextPageToken;

  @override
  int get count => _documents.count;

  ListResults(this._documents, this._nextPageToken) : super();
  ListResults.fail(LooseError error) : super.fail(error);
}
