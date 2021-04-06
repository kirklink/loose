import 'loose_response.dart';
import '../document_response.dart';

class ListResults<T> extends LooseListResponse {
  final String nextPageToken;

  ListResults(List<DocumentResponse<T>> responses, this.nextPageToken)
      : super(responses);
  ListResults.fail(LooseError error)
      : nextPageToken = '',
        super.fail(error);
}
