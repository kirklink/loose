import 'dart:math' show Random;
import 'document.dart';
import 'collection.dart';

class Counter extends Collection {
  static const String counterFieldName = 'c';
  static const Map<String, String> fieldPath = {'fieldPath': counterFieldName};

  final int _numShards;

  Counter(Document document, [this._numShards = 1]) : super(document, 'shards');

  Document shard() {
    final random = Random().nextInt(_numShards).toString();
    return Document(this, random);
  }
}
