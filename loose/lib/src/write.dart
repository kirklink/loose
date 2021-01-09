import 'dart:math' show Random;
import 'dart:convert' show base64;
import 'document_shell.dart';
import 'documenter.dart';
import 'constants.dart' show dynamicNameToken;
import 'loose_exception.dart';
import 'loose.dart';
import 'query/query_field.dart';
import 'counter.dart';

Future<String> _generateId() async {
  final random = Random.secure();
  final values = List<int>.generate(20, (index) => random.nextInt(256));
  var key = base64.encode(values);
  if (key.length > 20) {
    key = List<String>.generate(20, (index) => key[random.nextInt(key.length)])
        .join();
  }
  key = key.replaceAll('/', '_');
  return key;
}

abstract class Writable {
  Future<Map<String, Object>> encode([String databaseRoot = '']);
  String get label;
}

class WriteCreate<T extends DocumentShell<S>, S, R extends DocumentFields,
    Q extends QueryField> implements Writable {
  bool _autoAssignId = false;
  List<String> _idPath;
  Documenter<T, S, R> _document;
  Loose _loose;
  List<FieldTransform> _transforms;
  @override
  final String label;

  WriteCreate(Documenter<T, S, R> document,
      {List<String> idPath = const [],
      bool autoAssignId = false,
      Loose checkIdWith,
      List<FieldTransform> transforms = const [],
      this.label = ''}) {
    _autoAssignId = autoAssignId;
    _idPath = idPath;
    _document = document;
    _loose = checkIdWith;
    _transforms = transforms;
  }

  Future<String> _getCleanId(String databaseRoot, String workingPath) async {
    var y = 1;
    for (var x = 0; x <= y; x++) {
      final id = await _generateId();
      final documentName = '${databaseRoot}${workingPath}/${id}';
      final path = List<String>.from(_idPath, growable: true)
        ..add(documentName);
      final tryAgain = await _loose.exists(_document,
          idPath: path, keepClientOpen: true, bypassTransaction: true);
      if (!tryAgain) {
        return documentName;
      } else {
        y++;
      }
    }
  }

  @override
  Future<Map<String, Object>> encode([String databaseRoot = '']) async {
    if (_document.location.name == dynamicNameToken &&
        _idPath.isEmpty &&
        !_autoAssignId) {
      throw LooseException(
          'A name is required for this document but was not provided in idPath.');
    }

    var docId = '';
    if (_document.location.name == dynamicNameToken && !_autoAssignId) {
      docId = _idPath.removeLast();
    }

    var workingPath = '${_document.location.path}';

    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;

    if (ancestorCount != _idPath.length) {
      throw LooseException(
          '${_idPath.length} ancestor ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in _idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    final document = _document.toFirestoreFields();

    if (docId.isNotEmpty) {
      document.addAll({'name': '${databaseRoot}${workingPath}/${docId}'});
    } else {
      var documentName = '';
      if (_loose != null) {
        documentName = await _getCleanId(databaseRoot, workingPath);
      }

      document.addAll({'name': documentName});
    }

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

class WriteUpdate<T extends DocumentShell<S>, S, R extends DocumentFields,
    Q extends QueryField> implements Writable {
  final List<String> _idPath;
  final Documenter<T, S, R> _document;
  final List<Q> _updateFields;
  List<FieldTransform> _transforms;
  @override
  final String label;

  WriteUpdate(
    this._document,
    this._idPath,
    this._updateFields, {
    List<FieldTransform> transforms,
    this.label = '',
  }) {
    _transforms = transforms;
  }

  @override
  Future<Map<String, Object>> encode([String databaseRoot = '']) async {
    var workingPath =
        '${databaseRoot}/${_document.location.collection}/${_document.location.name}';
    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
    if (ancestorCount != _idPath.length) {
      throw LooseException(
          '${_idPath.length} document ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in _idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }
    final updateMask = {
      'fieldPaths': _updateFields.map((e) => e.name).toList()
    };
    final update = _document.toFirestoreFields();
    update.addAll({'name': workingPath});
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

class WriteDelete<T extends DocumentShell<S>, S, R extends DocumentFields>
    implements Writable {
  List<String> _idPath;
  final Documenter<T, S, R> _document;
  @override
  final String label;

  WriteDelete(
    this._document, {
    List<String> idPath = const [],
    this.label = '',
  }) {
    _idPath = idPath;
  }

  @override
  Future<Map<String, Object>> encode([String databaseRoot = '']) async {
    var workingPath =
        '${databaseRoot}/${_document.location.collection}/${_document.location.name}';
    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
    if (ancestorCount != _idPath.length) {
      throw LooseException(
          '${_idPath.length} document ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in _idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }
    final delete = workingPath;
    return {
      'delete': delete,
    };
  }
}

class WriteTransform<T extends DocumentShell<S>, S, R extends DocumentFields>
    implements Writable {
  List<String> _idPath;
  final Documenter<T, S, R> _document;
  final List<FieldTransform> _transforms;
  @override
  final String label;

  WriteTransform(
    this._document,
    this._transforms, {
    List<String> idPath = const [],
    this.label = '',
  }) {
    if (_transforms.isEmpty) {
      throw Exception('Field transforms cannot be empty.');
    }
    _idPath = idPath;
  }

  @override
  Future<Map<String, Object>> encode([String databaseRoot = '']) async {
    var workingPath =
        '${databaseRoot}/${_document.location.collection}/${_document.location.name}';
    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
    if (ancestorCount != _idPath.length) {
      throw LooseException(
          '${_idPath.length} document ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in _idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }
    final result = <String, Object>{'document': workingPath};
    result['fieldTransforms'] = _transforms.map((e) => e.transform).toList();
    return {'transform': result};
  }
}

class WriteCounter implements Writable {
  final Shard _shard;
  @override
  final String label;

  WriteCounter(
    this._shard, {
    this.label = '',
  });

  @override
  Future<Map<String, Object>> encode([String databaseRoot = '']) async {
    return {
      'transform': {
        'document': '${databaseRoot}${_shard.documentPath}',
        'fieldTransforms': [
          {
            'fieldPath': '${_shard.fieldPath}',
            'increment': {'integerValue': _shard.increment.toString()}
          }
        ]
      }
    };
  }
}

abstract class Write {
  // Write._();
  static WriteCreate<T, S, R, Q> create<T extends DocumentShell<S>, S,
      R extends DocumentFields, Q extends QueryField>(
    Documenter<T, S, R> document, {
    List<String> idPath = const [],
    bool autoAssignId = false,
    Loose checkIdWith,
    List<FieldTransform> transforms = const [],
    String label = '',
  }) {
    return WriteCreate(document,
        idPath: idPath,
        autoAssignId: autoAssignId,
        checkIdWith: checkIdWith,
        transforms: transforms,
        label: label);
  }

  static WriteUpdate<T, S, R, Q> update<T extends DocumentShell<S>, S,
      R extends DocumentFields, Q extends QueryField>(
    Documenter<T, S, R> document,
    List<String> idPath,
    List<Q> updateFields, {
    List<FieldTransform> transforms = const [],
    String label = '',
  }) {
    return WriteUpdate(document, idPath, updateFields,
        transforms: transforms, label: label);
  }

  static WriteDelete<T, S, R>
      delete<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Documenter<T, S, R> document,
          {List<String> idPath = const [],
          String label = ''}) {
    return WriteDelete(document, idPath: idPath, label: label);
  }

  static WriteTransform<T, S, R>
      transform<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Documenter<T, S, R> document, List<FieldTransform> transforms,
          {List<String> idPath = const [], String label = ''}) {
    return WriteTransform(document, transforms, idPath: idPath, label: label);
  }

  static WriteCounter count(
    Shard shard, {
    String label = '',
  }) =>
      WriteCounter(shard, label: label);
}

class FieldTransform {
  final QueryField _field;

  final _transform = <String, Object>{};
  Map<String, Object> get transform =>
      Map.from(_transform)..addAll(_field.fieldPath);

  FieldTransform(this._field);

  void _checkDone() {
    if (_transform.isNotEmpty) {
      throw Exception('Transform has already been set.');
    }
  }

  FieldTransform increment([int by = 1]) {
    _checkDone();
    if (_field is! IntegerField) {
      throw Exception('Increment must be on an integer field.');
    }
    _transform['increment'] = {'integerValue': by.toString()};
    return this;
  }

  FieldTransform decrement([int by = 1]) {
    _checkDone();
    if (_field is! IntegerField) {
      throw Exception('Decrement must be on an integer field.');
    }
    _transform['increment'] = {'integerValue': (by * -1).toString()};
    return this;
  }

  FieldTransform add(num number) {
    _checkDone();
    if (_field is! DoubleField) {
      throw Exception('Add must be on a double field.');
    }
    _transform['increment'] = {'doubleValue': number};
    return this;
  }

  FieldTransform subtract(num number) {
    _checkDone();
    if (_field is! DoubleField) {
      throw Exception('Subtract must be on a double field.');
    }
    _transform['increment'] = {'doubleValue': (number * -1)};
    return this;
  }

  FieldTransform maximum(num number) {
    _checkDone();
    if (_field is! DoubleField) {
      throw Exception('Maximum must be on a double field.');
    }
    _transform['maximum'] = {'doubleValue': number};
    return this;
  }

  FieldTransform minimum(num number) {
    _checkDone();
    if (_field is! DoubleField) {
      throw Exception('Minimum must be on a double field.');
    }
    _transform['minimum'] = {'doubleValue': number};
    return this;
  }

  FieldTransform serverTimestamp() {
    _checkDone();
    if (_field is! DateTimeField) {
      throw Exception('Server timestamp must be on a timestamp field.');
    }
    _transform['setToServerValue'] = 'REQUEST_TIME';
    return this;
  }
}
