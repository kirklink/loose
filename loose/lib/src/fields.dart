import 'query/query_field.dart';

abstract class Fields {
  Map<String, Object> get $fieldsMap;

  QueryField get(String fieldName) {
    return $fieldsMap[fieldName] as QueryField;
  }

  List<QueryField> $all() {
    final r = <QueryField>[];
    for (final v in $fieldsMap.values) {
      if (v is List<QueryField>) {
        r.addAll(v);
      } else {
        r.add(v as QueryField);
      }
    }
    return r;
  }
}
