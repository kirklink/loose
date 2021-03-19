import 'documenter.dart';
import 'document_shell.dart';

class UpdateMask<T extends DocumentResponse<S>, S, R extends DocumentFields> {
  final Documenter<T, S, R> _document;

  UpdateMask(this._document);

  R get fields => _document.fields;
}
