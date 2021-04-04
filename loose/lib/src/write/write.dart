import 'dart:math' as math;

import '../document_request.dart';
import '../constants.dart';
import '../loose.dart';
import '../counter.dart';
import '../document_field.dart';
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

  WriteUpdate<T> update(T entity, List<DocumentField> updateFields,
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
  final List<Transformer> _transforms;
  final T _entity;
  @override
  final String label;
  final String _workingPath;
  @override
  String get name => _workingPath;

  WriteCreate(this._request, this._entity, List<String> idPath,
      this._autoAssignId, this._transforms, this.label)
      : _workingPath = _request.document.resolvePath(idPath, _autoAssignId);

  @override
  Map<String, Object> write(Loose loose) {
    final document = _request.toFirestore(_entity);

    var path = '${loose.documentRoot}${_workingPath}';
    if (_autoAssignId) {
      path = path.replaceFirst(dynamicNameToken, _generateId());
    }
    document.addAll({'name': path});

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
  final List<DocumentField> _updateFields;
  final List<Transformer> _transforms;
  final T _entity;
  @override
  final String label;
  final String _workingPath;
  @override
  String get name => _workingPath;

  WriteUpdate(this._request, this._entity, this._updateFields,
      List<String> idPath, this._transforms, this.label)
      : _workingPath = _request.document.resolvePath(idPath);

  @override
  Map<String, Object> write(Loose loose) {
    final updateMask = {
      'fieldPaths': _updateFields.map((e) => e.name).toList()
    };
    final path = '${loose.documentRoot}${_workingPath}';
    final update = _request.toFirestore(_entity);
    update.addAll({'name': path});
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
  @override
  final String label;
  final String _workingPath;
  @override
  String get name => _workingPath;

  WriteDelete(DocumentRequest request, List<String> idPath, this.label)
      : _workingPath = request.document.resolvePath(idPath);

  @override
  Map<String, Object> write(Loose loose) {
    final path = '${loose.documentRoot}${_workingPath}';
    return {
      'delete': path,
    };
  }
}

class WriteTransform implements Writable {
  final List<Transformer> _transforms;
  @override
  final String label;
  final String _workingPath;
  @override
  String get name => _workingPath;

  WriteTransform(DocumentRequest request, this._transforms, List<String> idPath,
      this.label)
      : _workingPath = request.document.resolvePath(idPath);

  @override
  Map<String, Object> write(Loose loose) {
    final path = '${loose.documentRoot}${_workingPath}';
    final result = <String, Object>{'document': path};
    result['fieldTransforms'] = _transforms.map((e) => e.transform()).toList();
    return {'transform': result};
  }
}

class WriteCounter implements Writable {
  final int _increment;
  @override
  final String label;
  final String _workingPath;
  @override
  String get name => _workingPath;

  WriteCounter(
      Counter counter, this._increment, List<String> idPath, this.label)
      : _workingPath = counter.shard().resolvePath(idPath);

  @override
  Map<String, Object> write(Loose loose) {
    final path = '${loose.documentRoot}${_workingPath}';
    return {
      'transform': {
        'document': path,
        'fieldTransforms': [
          {
            ...Counter.fieldPath,
            'increment': {'integerValue': _increment.toString()}
          }
        ]
      }
    };
  }
}
