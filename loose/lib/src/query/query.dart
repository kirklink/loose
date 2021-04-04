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
      this.filter,
      this.orderBy = const [],
      this.limit,
      this.offset})
      : _workingPath =
            request.document.parent?.parent?.resolvePath(idPath) ?? '';

  Map<String, Object> encode() {
    final structuredQuery = <String, Object>{
      'from': [
        {'collectionId': request.document.parent.id}
      ]
    };
    if (filter != null) {
      structuredQuery.addAll({'where': filter?.encode() ?? const {}});
    }
    if (orderBy.isNotEmpty) {
      structuredQuery
          .addAll({'orderBy': orderBy.map((e) => e.encode).toList()});
    }
    if (offset != null) {
      structuredQuery.addAll({'offset': offset});
    }
    if (limit != null) {
      structuredQuery.addAll({'limit': limit});
    }
    return {'structuredQuery': structuredQuery};
  }
}
