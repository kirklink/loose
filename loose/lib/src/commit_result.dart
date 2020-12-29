import 'package:loose/src/write_results.dart';

class CommitResult {
  final WriteResults writeResults;
  final String _commitTime;

  bool get ok => commitTime != null;
  DateTime get commitTime => DateTime.tryParse(_commitTime ?? '');

  const CommitResult(this.writeResults, this._commitTime);
}
