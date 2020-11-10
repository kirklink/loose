import 'package:loose/src/documenter.dart';
import 'package:loose/src/document_shell.dart';

class UpdateMask<T extends DocumentShell<S>, S, R extends QueryFields> {
  final Documenter<T, S, R> _document;

  UpdateMask(this._document);

  R get fields => _document.queryFields;
}
