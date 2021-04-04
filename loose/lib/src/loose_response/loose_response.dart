import '../document_response.dart';
import '../loose_exception.dart';

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

abstract class LooseResponse {
  LooseError _error;

  bool get ok => LooseError.empty == _error;
  LooseError get error => _error;
  int get count;

  LooseResponse() {
    _error = LooseError.empty;
  }

  LooseResponse.fail(this._error);
}

class LooseEntityResponse<T> extends LooseResponse {
  DocumentResponse<T> _response;

  @override
  int get count => ok ? 1 : 0;

  LooseEntityResponse(this._response) : super();

  LooseEntityResponse.fail(LooseError error) : super.fail(error);

  T get entity {
    if (!ok) {
      throw LooseException(
          'No document was returned. Handle error if LooseResponse.ok is not true.');
    }
    return _response.entity;
  }

  DocumentResponse<T> get document {
    if (!ok) {
      throw LooseException(
          'No document was returned. Handle error if LooseResponse.ok is not true.');
    }
    return _response;
  }
}

class LooseListResponse<T> extends LooseResponse {
  List<DocumentResponse<T>> _responseList;

  @override
  int get count => ok ? _responseList.length : 0;

  LooseListResponse(this._responseList) : super();

  LooseListResponse.fail(LooseError error) : super.fail(error);

  List<T> get entities {
    if (!ok) {
      throw LooseException(
          'No documents were returned. Handle error if LooseResponse.ok is not true.');
    }
    return _responseList.map((DocumentResponse<T> e) => e.entity).toList();
  }

  List<DocumentResponse<T>> get documents {
    if (!ok) {
      throw LooseException(
          'No document was returned. Handle error if LooseResponse.ok is not true.');
    }
    return _responseList;
  }
}
