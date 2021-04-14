import 'document.dart';
import 'document_response.dart';

abstract class DocumentRequest<T> {
  Document get document;

  DocumentRequest();

  Map<String, Object> toFirestore(T entity);
  DocumentResponse<T> fromFirestore(Map<String, dynamic> m);
}
