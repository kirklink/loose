


import 'package:loose/src/document_shell.dart';
import 'package:loose/src/loose_exception.dart';

class LooseError {

 final int code;
 final String message;

 const LooseError._([this.code, this.message]);
 const LooseError(this.code, this.message);

 static const LooseError empty = LooseError._();

 bool get isEmpty => code == null && message == null;
 bool get isNotEmpty => !isEmpty;

}


class LooseResponse<T extends DocumentShell<S>, S> {
  DocumentShell<S> _shell;
  List<T> _shellList;
  bool _isList = false;
  final LooseError error;

  bool get success => error.isEmpty;

  int get count => !success ? 0 : !_isList ? 1 : _shellList.length;

  
  LooseResponse.single(T shell, [this.error = LooseError.empty]) {
    _isList = false;
    _shell = shell;
    _shellList = const [];
  }

  LooseResponse.list(List<T> list, [this.error = LooseError.empty]) {
    _isList = true;
    _shell = DocumentShell.empty as T;
    _shellList = list;
  }

  void _singleMethod() {
    if (_isList) {
      throw LooseException('This method cannot be used when expecting a document list response.');
    }
  }

  void _listMethod() {
    if (!_isList) {
      throw LooseException('This method cannot be used when expecting a single document response.');
    }
  }
  
  S get entity {
    _singleMethod();
    return _shell.entity;
  }

  DocumentShell<S> get document {
    _singleMethod();
    return _shell;
  }

  List<T> get list {
    _listMethod();
    return _shellList;
  }
  

}