import 'package:loose/src/batch_get_result.dart';
import 'package:loose/src/loose_response.dart';
import 'package:loose/src/write_results.dart';

class CommitResult extends LooseResponse {
  WriteResults _writeResults;
  String _commitTime;

  @override
  bool get ok => commitTime != null;

  @override
  int get count => _writeResults.results.length;

  DateTime get commitTime => DateTime.tryParse(_commitTime ?? '');

  CommitResult(this._writeResults, this._commitTime) : super();
  CommitResult.fail(LooseError error) : super.fail(error);
}
