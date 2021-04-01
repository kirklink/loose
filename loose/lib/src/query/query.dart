import '../loose_exception.dart';
// import '../documenter.dart';
// import '../document_shell.dart';
import '../document.dart';
import '../document_request.dart';
import 'filter.dart';
import 'order.dart';

class Query<T> {
  final DocumentRequest<T> request;
  Filter _filter;
  final _orders = <Order>[];
  int _limit;
  int _offset;

  // final Document document;

  Query(this.request);

  // R get fields => document.fields;

  void filter(Filter filter) {
    if (_filter != null) {
      throw LooseException(
          'Attempting to change a filter which has already been set.');
    }
    _filter = filter;
  }

  // Filter filter = Filter();

  void order(List<Order> orders) {
    if (_orders.isNotEmpty) {
      throw LooseException('The order has already been set on this query.');
    }
    _orders.addAll(orders);
  }

  void limit(int value) {
    if (_limit != null) {
      throw LooseException(
          'Attempting to change a limit which has already been set.');
    }
    if (value < 0) {
      throw LooseException(
          'The query limit must be >= 0. "$value" was provided.');
    }
    _limit = value;
  }

  void offset(int value) {
    if (_offset != null) {
      throw LooseException(
          'Attempting to change an offset which has already been set.');
    }
    if (value < 0) {
      throw LooseException(
          'The query offset must be >= 0. "$value" was provided.');
    }
    _offset = value;
  }

  Map<String, Object> encode() {
    final structuredQuery = <String, Object>{
      'from': [
        {'collectionId': request.document.parent.id}
      ]
    };
    if (_filter != null) {
      structuredQuery.addAll({'where': _filter?.encode() ?? const {}});
    }
    if (_orders.isNotEmpty) {
      structuredQuery
          .addAll({'orderBy': _orders.map((e) => e.encode).toList()});
    }
    if (_offset != null) {
      structuredQuery.addAll({'offset': _offset});
    }
    if (_limit != null) {
      structuredQuery.addAll({'limit': _limit});
    }
    return {'structuredQuery': structuredQuery};
  }
}
