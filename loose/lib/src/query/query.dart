import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/documenter.dart';
import 'package:loose/src/document_shell.dart';
import 'package:loose/src/query/filter.dart';
import 'package:loose/src/query/order.dart';


class Query<T extends DocumentShell<S>, S, R extends QueryFields> {
  
  BaseFilter _filter;
  final _orders = <Order>[];

  final Documenter<T, S, R> document;

  Query(this.document);

  R get fields => document.queryFields;
  
  void filter(BaseFilter filter) {
    if (_filter != null) {
      throw LooseException('Attempting to change a filter which has already been set.');
    }
    _filter = filter;
  }

  void orderBy(Order order) {
    _orders.add(order);
  }


  Map<String, Object> get result {
    return {
      'structuredQuery': {
        'from': [
          {
            'collectionId': document.location.collection
          }
        ],
        'where': _filter.result,
        'orderBy': _orders.map((e) => e.product).toList()
      }
    };
  }
}