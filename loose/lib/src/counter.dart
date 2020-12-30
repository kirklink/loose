import 'dart:math' show Random;
import 'package:loose/src/document.dart';
import 'package:loose/src/loose_exception.dart';

class Counter {
  final Document _document;
  final int _numShards;
  final String fieldPath = 'c';

  List<String> get shards {
    final paths = <String>[];
    for (var i = 0; i < _numShards; i++) {
      paths.add('${_document.path}/shards/$i');
    }
    return paths;
  }

  String get location => '${_document.path}/shards';

  Counter._(this._document, this._numShards);

  factory Counter(Document document, [int numShards = 1]) {
    if (numShards > 999) {
      throw LooseException('Maximum number of shards is 999.');
    }
    return _counters.putIfAbsent(
        document.path, () => Counter._(document, numShards));
  }

  int _getId() {
    final random = Random();
    return random.nextInt(_numShards);
  }

  Shard increase([int by = 1]) {
    final id = _getId();
    return Shard('${_document.path}/shards/$id', fieldPath, by);
  }

  Shard decrease([int by = 1]) {
    final id = _getId();
    return Shard('${_document.path}/shards/$id', fieldPath, (by * -1));
  }

  static final _counters = <String, Counter>{};
}

class Shard {
  final String documentPath;
  final String fieldPath;
  final int increment;
  Shard(this.documentPath, this.fieldPath, this.increment);
}
