import 'package:loose/annotations.dart';

import 'loose_response.dart';

class BatchGetResults<T> extends LooseListResponse {
  final List<String> _missing;
  List<String> get missing => List.unmodifiable(_missing);

  BatchGetResults(List<DocumentResponse<T>> found, this._missing)
      : super(found);
  BatchGetResults.fail(LooseError error)
      : _missing = const [],
        super.fail(error);
}
