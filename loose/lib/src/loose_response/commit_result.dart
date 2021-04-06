import 'loose_response.dart';
import '../write/write_results.dart';

class CommitResult extends LooseResponse {
  final WriteResults _writeResults;
  final String _commitTime;

  @override
  bool get ok => _commitTime.isNotEmpty;

  @override
  int get count => _writeResults.results.length;

  // DateTime get commitTime =>
  //     DateTime.tryParse(_commitTime ?? '') ?? DateTime(0);

  // WriteResults get writeResults => _writeResults;

  CommitResult(this._writeResults, this._commitTime) : super();
  CommitResult.fail(LooseError error)
      : _writeResults = WriteResults.empty,
        _commitTime = '',
        super.fail(error);
}
