


import 'package:loose/src/document_shell.dart';
import 'package:loose/src/loose_exception.dart';

class LooseResponse<T extends DocumentShell<S>, S> {
  DocumentShell<S> _shell;
  List<T> _shellList;
  bool _isList;
  final bool success;
  final int error;

  
  LooseResponse.single(T shell, this.success, [this.error = 0]) {
    _isList = false;
    _shell = shell;
    _shellList = const [];
  }

  LooseResponse.list(List<T> list, this.success, [this.error = 0]) {
    _isList = true;
    _shell = DocumentShell.empty<S>();
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