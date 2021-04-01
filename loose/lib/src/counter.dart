import 'dart:math' show Random;
import 'document.dart';
import 'loose_exception.dart';

class Counter {
  final _countField = 'c';

  final Document document;
  final int _numShards;

  Map<String, String> get fieldPath => {'fieldPath': '${_countField}'};
  String get counterField => _countField;
  String get collection => '${document.path}/shards';

  Counter(this.document, [this._numShards = 1]);

  String shard() => Random().nextInt(_numShards).toString();
}

// class Shard {
//   final String documentPath;
//   final String fieldPath;
//   final int increment;
//   Shard(this.documentPath, this.fieldPath, this.increment);
// }
