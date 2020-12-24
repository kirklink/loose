import 'package:loose/src/write.dart';

class _BatchWriteResult {
  final String updateTime;
  final Map<String, Object> status;
  final Writable write;

  String get label => write.label;
  bool get success => status.isEmpty;

  const _BatchWriteResult(this.updateTime, this.status, this.write);
}

class BatchWriteResults {
  final List<_BatchWriteResult> _results;
  List<_BatchWriteResult> get results => List.from(_results);
  bool get hasResults => _results.isNotEmpty;
  bool get hasErrors => _results.any((e) => !e.success);

  const BatchWriteResults._empty([this._results = const []]);

  BatchWriteResults._(this._results);

  factory BatchWriteResults(
      List<Writable> writes, Map<String, Object> rawResults) {
    final list = <_BatchWriteResult>[];
    final updates = rawResults['writeResults'] as List<Object>;
    final status = rawResults['status'] as List<Object>;
    for (var i = 0; i < writes.length; i++) {
      list.add(_BatchWriteResult(
          (updates[i] as Map<String, Object>)['updateTime'] as String,
          (status[i] as Map<String, Object>)['status'] as Map<String, Object>,
          writes[i]));
    }
    return BatchWriteResults._(list);
  }

  static const BatchWriteResults empty = BatchWriteResults._empty();
}
