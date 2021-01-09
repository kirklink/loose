import 'document_shell.dart';
import 'loose_response.dart';

class BatchGetResults<T extends DocumentShell<S>, S> extends LooseResponse {
  LooseListResponse<T, S> _found;
  LooseListResponse<T, S> get found => _found;
  List<String> _missing;
  List<String> get missing => _missing;

  @override
  int get count => _found.count;

  BatchGetResults(this._found, this._missing) : super();
  BatchGetResults.fail(LooseError error) : super.fail(error);
}
