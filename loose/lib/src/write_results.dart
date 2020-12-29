import 'package:loose/src/write.dart';

class _WriteResult {
  final String _updateTime;
  final Map<String, Object> status;
  final Writable write;

  String get label => write.label;
  DateTime get updateTime => DateTime.tryParse(_updateTime ?? '');
  bool get ok => updateTime != null;

  const _WriteResult(this._updateTime, this.status, this.write);
}

class WriteResults {
  final List<_WriteResult> _results;
  List<_WriteResult> get results => List.from(_results);
  bool get hasResults => _results.isNotEmpty;
  bool get hasErrors => _results.any((e) => !e.ok);

  const WriteResults._empty([this._results = const []]);

  WriteResults._(this._results);

  factory WriteResults(List<Writable> writes, Map<String, Object> rawResults) {
    final list = <_WriteResult>[];
    final updates = rawResults['writeResults'] as List<Object>;
    final status = (rawResults['status'] ?? const []) as List<Object>;
    for (var i = 0; i < writes.length; i++) {
      // Not all write results have the status
      // Especially writes on transaction commits
      list.add(_WriteResult(
          (updates[i] as Map<String, Object>)['updateTime'] as String,
          status.isNotEmpty ? status[i] as Map<String, Object> : const {},
          writes[i]));
    }
    return WriteResults._(list);
  }

  static const WriteResults empty = WriteResults._empty();
}
