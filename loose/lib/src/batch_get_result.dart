import 'loose_response.dart';

class BatchGetResults<T> {
  LooseListResponse<T> _found;
  LooseListResponse<T> get found => _found;
  List<String> _missing;
  List<String> get missing => _missing;

  int get count => _found.count;

  BatchGetResults(this._found, this._missing);
  BatchGetResults.fail(LooseError error);
}
