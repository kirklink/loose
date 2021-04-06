import '../document_response.dart';
import '../loose_exception.dart';

class LooseError {
  final int code;
  final String internalMessage;
  final String serverMessage;

  bool get isNotFound => 404 == code;

  const LooseError(this.code, this.internalMessage, this.serverMessage);

  const LooseError._empty()
      : code = 0,
        internalMessage = '',
        serverMessage = '';

  static const LooseError empty = LooseError._empty();
}

abstract class LooseResponse {
  final LooseError _error;

  bool get ok => LooseError.empty == _error;
  LooseError get error => _error;
  int get count;

  LooseResponse() : _error = LooseError.empty;

  LooseResponse.fail(this._error);
}

class LooseEntityResponse<T> extends LooseResponse {
  final DocumentResponse<T> _response;

  @override
  int get count => ok && _response.isNotEmpty ? 1 : 0;

  LooseEntityResponse(this._response) : super();

  LooseEntityResponse.fail(LooseError error, this._response)
      : super.fail(error);

  T get entity {
    final e = _response.entity;
    if (e == null) {
      throw LooseException(
          'No document was returned. Handle error if LooseResponse.ok is not true.');
    }
    return e;
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
  final List<DocumentResponse<T>> _responseList;

  @override
  int get count => ok ? _responseList.length : 0;

  LooseListResponse(this._responseList) : super();

  LooseListResponse.fail(LooseError error)
      : _responseList = const [],
        super.fail(error);

  List<T> get entities {
    return _responseList.map((DocumentResponse<T> e) {
      final r = e.entity;
      if (r == null) {
        throw LooseException('Null documents were returned.');
      }
      return r;
    }).toList();
  }

  List<DocumentResponse<T>> get documents {
    if (!ok) {
      throw LooseException(
          'No document was returned. Handle error if LooseResponse.ok is not true.');
    }
    return _responseList;
  }
}
