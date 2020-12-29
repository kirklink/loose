import 'package:loose/src/document_shell.dart';
import 'package:loose/src/loose_response.dart';

class ListResults<T extends DocumentShell<S>, S> {
  final LooseResponse<T, S> documents;
  final String nextPageToken;

  ListResults(this.documents, this.nextPageToken);
}
