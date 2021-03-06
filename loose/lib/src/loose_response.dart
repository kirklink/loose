import 'document_shell.dart';
import 'loose_exception.dart';

class LooseError {
  final int code;
  final String internalMessage;
  final String serverMessage;

  bool get isNotFound => 404 == code;

  const LooseError._(
      [this.code = 0, this.internalMessage = '', this.serverMessage = '']);
  const LooseError(this.code, this.internalMessage, this.serverMessage);

  static const LooseError empty = LooseError._();
}

abstract class LooseResponse<T extends DocumentShell<S>, S> {
  LooseError _error;

  bool get ok => LooseError.empty == _error;
  LooseError get error => _error;
  int get count;

  LooseResponse() {
    _error = LooseError.empty;
  }

  LooseResponse.fail(this._error);
}

class LooseEntityResponse<T extends DocumentShell<S>, S> extends LooseResponse {
  DocumentShell<S> _shell;

  @override
  int get count => ok ? 1 : 0;

  LooseEntityResponse(this._shell) : super();

  LooseEntityResponse.fail(LooseError error) : super.fail(error);

  S get entity {
    if (!ok) {
      throw LooseException(
          'No document was returned. Handle error if LooseResponse.ok is not true.');
    }
    return _shell.entity;
  }

  DocumentShell<S> get document {
    if (!ok) {
      throw LooseException(
          'No document was returned. Handle error if LooseResponse.ok is not true.');
    }
    return _shell;
  }
}

class LooseListResponse<T extends DocumentShell<S>, S> extends LooseResponse {
  List<T> _shellList;

  @override
  int get count => ok ? _shellList.length : 0;

  LooseListResponse(this._shellList) : super();

  LooseListResponse.fail(LooseError error) : super.fail(error);

  List<S> get entities {
    if (!ok) {
      throw LooseException(
          'No documents were returned. Handle error if LooseResponse.ok is not true.');
    }
    return _shellList.map((DocumentShell<S> e) => e.entity).toList();
  }

  List<T> get documents {
    if (!ok) {
      throw LooseException(
          'No document was returned. Handle error if LooseResponse.ok is not true.');
    }
    return _shellList;
  }
}
