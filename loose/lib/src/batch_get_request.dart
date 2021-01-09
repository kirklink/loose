import 'documenter.dart';
import 'document_shell.dart';
import 'document_info.dart';

class BatchGetRequest<T extends DocumentShell<S>, S, R extends DocumentFields> {
  final Documenter<T, S, R> document;
  final List<List<String>> _idPaths = [];
  List<List<String>> get idPaths => List.from(_idPaths, growable: false);
  DocumentInfo get location => document.location;
  BatchGetRequest(this.document);

  void addIdPath(List<String> idPath) {
    idPaths.add(idPath);
  }
}
