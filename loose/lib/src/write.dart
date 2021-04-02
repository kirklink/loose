import 'dart:math' as math;

import 'document_request.dart';
import 'constants.dart';
import 'loose.dart';
import 'loose_exception.dart';
import 'counter.dart';
import 'query/query_field.dart';
import 'transformer.dart';

class Write<T> {
  final DocumentRequest<T> _request;

  Write(this._request);

  WriteCreate<T> create(T entity,
      {List<String> idPath = const [],
      bool autoAssignId = false,
      List<Transformer> transforms = const [],
      String label = ''}) {
    return WriteCreate(
        _request, entity, idPath, autoAssignId, transforms, label);
  }

  WriteUpdate<T> update(T entity, List<QueryField> updateFields,
      {List<String> idPath = const [],
      List<Transformer> transforms = const [],
      String label = ''}) {
    return WriteUpdate(
        _request, entity, updateFields, idPath, transforms, label);
  }

  WriteDelete delete({
    List<String> idPath = const [],
    String label = '',
  }) {
    return WriteDelete(_request, idPath, label);
  }

  WriteTransform transform(List<Transformer> tranformers,
      {List<String> idPath = const [], String label = ''}) {
    return WriteTransform(_request, tranformers, idPath, label);
  }

  static WriteCountHandler counter(Counter counter,
      {List<String> idPath = const []}) {
    return WriteCountHandler(counter, idPath);
  }
}

class WriteCountHandler {
  final Counter _counter;
  final List<String> _idPath;
  WriteCountHandler(this._counter, this._idPath);
  WriteCounter increase({int by = 1, String label = ''}) {
    return WriteCounter(_counter, by, _idPath, label);
  }

  WriteCounter decrease({int by = 1, String label = ''}) {
    return WriteCounter(_counter, by * -1, _idPath, label);
  }
}

abstract class Writable {
  Map<String, Object> write(Loose loose);
  String get label;
  String get name;
}

String _generateId() {
  // https://stackoverflow.com/questions/55674071/firebase-firestore-addding-new-document-inside-a-transaction-transaction-add-i
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  var autoId = '';
  for (var i = 0; i < 20; i++) {
    autoId += chars[math.Random.secure().nextInt(chars.length)];
  }
  return autoId;
}

class WriteCreate<T> implements Writable {
  final DocumentRequest<T> _request;
  final bool _autoAssignId;
  List<String> _idPath;
  final List<Transformer> _transforms;
  final T _entity;
  @override
  final String label;
  String _workingPath = '';
  @override
  String get name => _workingPath;

  WriteCreate(this._request, this._entity, List<String> idPath,
      this._autoAssignId, this._transforms, this.label) {
    _idPath = List.of(idPath);
    if (_autoAssignId) {
      _idPath.add(_generateId());
    }
    final tokenCount =
        dynamicNameToken.allMatches(_request.document.path).length;
    if (tokenCount != _idPath.length) {
      throw LooseException(
          '${_idPath.length} ids provided and $tokenCount are required.');
    }

    _workingPath = _request.document.path;

    for (final id in _idPath) {
      _workingPath = _workingPath.replaceFirst(dynamicNameToken, id);
    }
  }

  @override
  Map<String, Object> write(Loose loose) {
    final document = _request.toFirestore(_entity);

    var name = '${loose.documentRoot}${_workingPath}';

    document.addAll({'name': name});

    final currentDocument = {'exists': false};

    final result = <String, Object>{
      'currentDocument': currentDocument,
      'update': document
    };

    if (_transforms.isNotEmpty) {
      result['updateTransforms'] = _transforms.map((e) => e.transform).toList();
    }

    return result;
  }
}

class WriteUpdate<T> implements Writable {
  final DocumentRequest<T> _request;
  final List<QueryField> _updateFields;
  final List<String> _idPath;
  final List<Transformer> _transforms;
  final T _entity;
  @override
  final String label;
  String _workingPath;
  @override
  String get name => _workingPath;

  WriteUpdate(this._request, this._entity, this._updateFields, this._idPath,
      this._transforms, this.label) {
    final tokenCount =
        dynamicNameToken.allMatches(_request.document.path).length;
    if (tokenCount != _idPath.length) {
      throw LooseException(
          '${_idPath.length} ids provided and $tokenCount are required.');
    }
    _workingPath = '${_request.document.path}';

    for (final id in _idPath) {
      _workingPath = _workingPath.replaceFirst(dynamicNameToken, id);
    }
  }

  @override
  Map<String, Object> write(Loose loose) {
    final updateMask = {
      'fieldPaths': _updateFields.map((e) => e.name).toList()
    };
    final name = '${loose.documentRoot}${_workingPath}';
    final update = _request.toFirestore(_entity);
    update.addAll({'name': name});
    final currentDocument = {'exists': true};
    final result = <String, Object>{
      'updateMask': updateMask,
      'currentDocument': currentDocument,
      'update': update
    };
    if (_transforms.isNotEmpty) {
      result['updateTransforms'] = _transforms.map((e) => e.transform).toList();
    }
    return result;
  }
}

class WriteDelete implements Writable {
  final DocumentRequest _request;
  final List<String> _idPath;
  @override
  final String label;
  String _workingPath;
  @override
  String get name => _workingPath;

  WriteDelete(this._request, this._idPath, this.label) {
    final tokenCount =
        dynamicNameToken.allMatches(_request.document.path).length;
    if (tokenCount != _idPath.length) {
      throw LooseException(
          '${_idPath.length} ids provided and $tokenCount are required.');
    }
    _workingPath = '${_request.document.path}';
    for (final id in _idPath) {
      _workingPath = _workingPath.replaceFirst(dynamicNameToken, id);
    }
  }

  @override
  Map<String, Object> write(Loose loose) {
    final name = '${loose.documentRoot}${_workingPath}';
    return {
      'delete': name,
    };
  }
}

class WriteTransform implements Writable {
  final DocumentRequest _request;
  final List<String> _idPath;
  final List<Transformer> _transforms;
  @override
  final String label;
  String _workingPath;
  @override
  String get name => _workingPath;

  WriteTransform(this._request, this._transforms, this._idPath, this.label) {
    final tokenCount =
        dynamicNameToken.allMatches(_request.document.path).length;
    if (tokenCount != _idPath.length) {
      throw LooseException(
          '${_idPath.length} ids provided and $tokenCount are required.');
    }
    var workingPath = '${_request.document.path}';

    for (final id in _idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }
  }

  @override
  Map<String, Object> write(Loose loose) {
    final name = '${loose.documentRoot}${_workingPath}';
    final result = <String, Object>{'document': name};
    result['fieldTransforms'] = _transforms.map((e) => e.transform()).toList();
    return {'transform': result};
  }
}

class WriteCounter implements Writable {
  final Counter _counter;
  final int _increment;
  final List<String> _idPath;
  @override
  final String label;
  String _workingPath;
  @override
  String get name => _workingPath;

  WriteCounter(this._counter, this._increment, this._idPath, this.label) {
    final tokenCount =
        dynamicNameToken.allMatches(_counter.document.path).length;
    if (tokenCount != _idPath.length) {
      throw LooseException(
          '${_idPath.length} ids provided and $tokenCount are required.');
    }
    _workingPath = '${_counter.collection}';

    for (final id in _idPath) {
      _workingPath = _workingPath.replaceFirst(dynamicNameToken, id);
    }
  }

  @override
  Map<String, Object> write(Loose loose) {
    final name = '${loose.documentRoot}${_workingPath}/${_counter.shard()}';
    return {
      'transform': {
        'document': name,
        'fieldTransforms': [
          {
            ..._counter.fieldPath,
            'increment': {'integerValue': _increment.toString()}
          }
        ]
      }
    };
  }
}
