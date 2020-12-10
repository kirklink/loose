import 'dart:math' show Random;
import 'dart:convert' show base64;
import 'package:loose/src/document_shell.dart';
import 'package:loose/src/documenter.dart';
import 'package:loose/src/constants.dart' show dynamicNameToken;
import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/loose.dart';
import 'package:loose/src/query/query_field.dart';

String _generateId() {
  final random = Random.secure();
  final values = List<int>.generate(20, (index) => random.nextInt(256));
  var key = base64.encode(values);
  if (key.length > 20) {
    key = List<String>.generate(20, (index) => key[random.nextInt(key.length)])
        .join();
  }
  return key;
}

abstract class Writable {
  Future<Map<String, Object>> encode(String databaseRoot);
}

class WriteCreate<T extends DocumentShell<S>, S, R extends QueryFields,
    Q extends QueryField> implements Writable {
  bool _autoAssignId = false;
  List<String> _idPath;
  Documenter<T, S, R> _document;
  Loose _loose;

  WriteCreate(Documenter<T, S, R> document,
      {List<String> idPath = const [],
      bool autoAssignId = false,
      Loose loose}) {
    _autoAssignId = autoAssignId;
    _idPath = idPath;
    _document = document;
    _loose = loose;
  }

  @override
  Future<Map<String, Object>> encode(String databaseRoot) async {
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
      var tryAgain = false;
      var documentName = '${databaseRoot}${workingPath}/${_generateId()}';
      if (_loose != null) {
        do {
          final path = List<String>.from(_idPath, growable: true)
            ..add(documentName);
          final r = await _loose.read(_document,
              idPath: path, keepClientOpen: true, bypassTransaction: true);
          tryAgain = r.errorCode == 404 ? false : true;
        } while (tryAgain);
      }

      document.addAll({'name': documentName});
    }

    final currentDocument = {'exists': false};

    return {'currentDocument': currentDocument, 'update': document};
  }
}

class WriteUpdate<T extends DocumentShell<S>, S, R extends QueryFields,
    Q extends QueryField> implements Writable {
  final List<String> _idPath;
  final Documenter<T, S, R> _document;
  final List<Q> _updateFields;

  WriteUpdate(this._document, this._idPath, this._updateFields);

  @override
  Future<Map<String, Object>> encode(String databaseRoot) async {
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
    return {
      'updateMask': updateMask,
      'currentDocument': currentDocument,
      'update': update
    };
  }
}

class WriteDelete<T extends DocumentShell<S>, S, R extends QueryFields>
    implements Writable {
  List<String> _idPath;
  final Documenter<T, S, R> _document;

  WriteDelete(this._document, {List<String> idPath = const []}) {
    _idPath = idPath;
  }

  @override
  Future<Map<String, Object>> encode(String databaseRoot) async {
    var workingPath =
        '${databaseRoot}/${_document.location.path}/${_document.location.name}';
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

class Write {
  Write._();
  static WriteCreate<T, S, R, Q> create<
          T extends DocumentShell<S>,
          S,
          R extends QueryFields,
          Q extends QueryField>(Documenter<T, S, R> document,
      {List<String> idPath = const [],
      bool autoAssignId = false,
      Loose loose}) {
    return WriteCreate(document,
        idPath: idPath, autoAssignId: autoAssignId, loose: loose);
  }

  static WriteUpdate<T, S, R, Q> update<T extends DocumentShell<S>, S,
          R extends QueryFields, Q extends QueryField>(
      Documenter<T, S, R> document, List<String> idPath, List<Q> updateFields) {
    return WriteUpdate(document, idPath, updateFields);
  }

  static WriteDelete<T, S, R>
      delete<T extends DocumentShell<S>, S, R extends QueryFields>(
          Documenter<T, S, R> document,
          {List<String> idPath = const []}) {
    return WriteDelete(document, idPath: idPath);
  }
}
