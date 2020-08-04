import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:loose/annotations.dart';
import 'package:loose/src/document_info.dart';

abstract class QueryFields {}

abstract class Documenter<T extends DocumentShell, S, R extends QueryFields> {
  Map<String, fs.Value> toFirestoreFields();
  T fromFirestore(Map<String, Value> fields, String name, String createTime, String updateTime);
  T from(S entity);
  DocumentInfo get location;
  R get queryFields;
  
}
