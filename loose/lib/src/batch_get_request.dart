import 'package:loose/src/documenter.dart';
import 'package:loose/src/document_shell.dart';
import 'package:loose/src/document_info.dart';

class BatchGetRequest<T extends DocumentShell<S>, S, R extends QueryFields> {
  final Documenter<T, S, R> document;
  final List<List<String>> _idPaths = [];
  List<List<String>> get idPaths => List.from(_idPaths, growable: false);
  DocumentInfo get location => document.location;
  BatchGetRequest(this.document);

  void addIdPath(List<String> idPath) {
    idPaths.add(idPath);
  }
}
