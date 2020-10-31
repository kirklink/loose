import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/documenter.dart';
import 'package:loose/src/document_shell.dart';
import 'package:loose/src/query/filter.dart';
import 'package:loose/src/query/order.dart';

class Query<T extends DocumentShell<S>, S, R extends QueryFields> {
  BaseFilter _filter;
  final _orders = <Order>[];
  int _limit;
  int _offset;

  final Documenter<T, S, R> document;

  Query(this.document);

  R get fields => document.queryFields;

  void filter(BaseFilter filter) {
    if (_filter != null) {
      throw LooseException(
          'Attempting to change a filter which has already been set.');
    }
    _filter = filter;
  }

  void orderBy(Order order) {
    _orders.add(order);
  }

  void limit(int value) {
    if (value < 0) {
      throw LooseException(
          'The query limit must be >= 0. "$value" was provided.');
    }
    _limit = value;
  }

  void offset(int value) {
    if (value < 0) {
      throw LooseException(
          'The query offset must be >= 0. "$value" was provided.');
    }
    _offset = value;
  }

  Map<String, Object> get encode {
    return {
      'structuredQuery': {
        'from': [
          {'collectionId': document.location.collection}
        ],
        'where': _filter?.encode,
        'orderBy': _orders.map((e) => e.encode).toList(),
        'offset': _offset,
        'limit': _limit,
      }
    };
  }
}
