import '../document_request.dart';
import 'filter.dart';
import 'sort_order.dart';

class Query<T> {
  final DocumentRequest<T> request;
  final Filter filter;
  final List<SortOrder> orderBy;
  final int limit;
  final int offset;
  final String _workingPath;

  String get location => _workingPath;

  Query(this.request,
      {List<String> idPath = const [],
      this.filter = Filter.empty,
      this.orderBy = const [],
      this.limit = 0,
      this.offset = 0})
      : _workingPath =
            request.document.parent.parent?.resolvePath(idPath) ?? '';

  Map<String, Object> encode() {
    final structuredQuery = <String, Object>{
      'from': [
        {'collectionId': request.document.parent.id}
      ]
    };
    if (filter != Filter.empty) {
      structuredQuery.addAll({'where': filter.encode()});
    }
    if (orderBy.isNotEmpty) {
      structuredQuery
          .addAll({'orderBy': orderBy.map((e) => e.encode).toList()});
    }
    if (offset != 0) {
      structuredQuery.addAll({'offset': offset});
    }
    if (limit != 0) {
      structuredQuery.addAll({'limit': limit});
    }
    return {'structuredQuery': structuredQuery};
  }
}
