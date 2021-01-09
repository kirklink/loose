import 'package:loose/annotations.dart';
import 'document_info.dart';

abstract class DocumentFields {}

abstract class Documenter<T extends DocumentShell, S,
    R extends DocumentFields> {
  Map<String, Object> toFirestoreFields();
  T fromFirestore(Map<String, Object> fields, String name, String createTime,
      String updateTime);
  T from(S entity);
  DocumentInfo get location;
  R get fields;
}
