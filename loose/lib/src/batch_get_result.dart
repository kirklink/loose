import 'package:loose/src/document_shell.dart';
import 'package:loose/src/loose_response.dart';

class BatchGetResults<T extends DocumentShell<S>, S> {
  final LooseListResponse<T, S> found;
  final List<String> missing;

  BatchGetResults(this.found, this.missing);
}
