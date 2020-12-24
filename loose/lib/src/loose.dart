import 'dart:convert' show json;
import 'package:googleapis_auth/auth_io.dart' as auth;

import 'package:loose/src/loose_credentials.dart';
import 'package:loose/src/documenter.dart';
import 'package:loose/src/document_shell.dart';
import 'package:loose/src/document_info.dart';
import 'package:loose/src/loose_response.dart';
import 'package:loose/src/reference.dart';
import 'package:loose/src/firestore_database.dart';
import 'package:loose/src/constants.dart';
import 'package:loose/src/write.dart';
import 'package:loose/src/batch_write_results.dart';
import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/query/query.dart';
import 'package:loose/src/query/query_field.dart';

import 'loose_exception.dart';

abstract class LooseErrors {
  static LooseError documentExists(String serverMessage) =>
      LooseError(409, 'Document already exists', serverMessage);
  static LooseError notFound(String serverMessage) =>
      LooseError(404, 'Document not found', serverMessage);
  static LooseError apiCallFailed(String serverMessage) =>
      LooseError(500, 'Call to Firestore failed.', serverMessage);
}

class Loose {
  final _SCOPES = const [cloudPlatformScope, datastoreScope];

  LooseCredentials _creds;
  auth.AutoRefreshingAuthClient _client;
  FirestoreDatabase _database;
  var _transactionId = '';

  String get documentRoot => _database.documentRoot;
  String get databaseRoot => _database.rootPath;
  bool get hasOpenClient => _client != null;

  Loose._(LooseCredentials credentials, FirestoreDatabase database) {
    _creds = credentials;
    _database = database;
  }

  factory Loose() {
    if (_cache == null) {
      throw LooseException('Loose has not been initialized with Loose.init()');
    }
    return _cache;
  }

  static void init(LooseCredentials credentials, FirestoreDatabase database) {
    if (_cache != null) {
      throw LooseException('Loose has already been initialized.');
    }
    _cache ??= Loose._(credentials, database);
  }

  static Loose _cache;

  Future<auth.AutoRefreshingAuthClient> _createClient() async {
    if (_creds.fromApplicationDefault) {
      return auth.clientViaApplicationDefaultCredentials(scopes: _SCOPES);
    } else {
      final jsonCreds = auth.ServiceAccountCredentials.fromJson({
        'private_key_id': _creds.privateKeyId,
        'private_key': _creds.privateKey,
        'client_email': _creds.clientEmail,
        'client_id': _creds.clientId,
        'type': _creds.type
      });
      return auth.clientViaServiceAccount(jsonCreds, _SCOPES);
    }
  }

  Reference reference(Documenter document, {List<String> idPath = const []}) {
    return Reference(document, _database, idPath: idPath);
  }

  void done() {
    if (_client != null) {
      _client.close();
      _client = null;
    }
  }

  // CREATE
  Future<LooseResponse<T, S>>
      create<T extends DocumentShell<S>, S, R extends QueryFields>(
          Documenter<T, S, R> document,
          {List<String> idPath = const [],
          bool autoAssignId = false,
          bool printFields = false,
          bool keepClientOpen = false}) async {
    if (document.location.name == dynamicNameToken &&
        idPath.isEmpty &&
        !autoAssignId) {
      throw LooseException(
          'A name is required for this document but was not provided in idPath.');
    }

    var docId = '';
    if (document.location.name == dynamicNameToken && !autoAssignId) {
      docId = idPath.removeLast();
    }

    var workingPath = '${document.location.path}';

    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;

    if (ancestorCount != idPath.length) {
      throw LooseException(
          '${idPath.length} ancestor ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    _client ??= await _createClient();

    final queryParameters = <String, String>{};
    // if (_transactionId.isNotEmpty) {
    //   queryParameters.addAll({'transaction': _transactionId});
    // }

    if (docId.isNotEmpty) {
      queryParameters.addAll({'documentId': docId});
    }

    final uri = Uri.https(
        authority, '${_database.rootPath}${workingPath}', queryParameters);

    final reqBody = document.toFirestoreFields();
    if (printFields) {
      print(json.encode(reqBody));
    }
    final res = await _client.post(uri, body: json.encode(reqBody));

    if (!keepClientOpen) {
      _client.close();
      _client = null;
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails<T, S>(res.statusCode, res.body);
    }

    final resBody = json.decode(res.body) as Map<String, Object>;

    final shell = document.fromFirestore(
        resBody['fields'] as Map<String, Object>,
        resBody['name'] as String,
        resBody['createTime'] as String,
        resBody['updateTime'] as String);
    return LooseResponse.single(shell);
  }

  // READ
  Future<LooseResponse<T, S>>
      read<T extends DocumentShell<S>, S, R extends QueryFields>(
    Documenter<T, S, R> document, {
    List<String> idPath = const [],
    bool keepClientOpen = false,
    bool bypassTransaction = false,
    bool ignoreContent = false,
  }) async {
    var workingPath = '${document.location.path}/${document.location.name}';

    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
    if (ancestorCount != idPath.length) {
      throw LooseException(
          '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    _client ??= await _createClient();

    final queryParameters = <String, String>{};
    if (_transactionId.isNotEmpty && !bypassTransaction) {
      queryParameters.addAll({'transaction': _transactionId});
    }

    final uri = Uri.https(
        authority, '${_database.rootPath}${workingPath}', queryParameters);
    final res = await _client.get(uri);

    if (!keepClientOpen) {
      _client.close();
      _client = null;
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails<T, S>(res.statusCode, res.body);
    }

    final resBody = json.decode(res.body);
    if (ignoreContent) {
      final shell = document.fromFirestore(const {}, '', '', '');
      return LooseResponse.single(shell);
    } else {
      final shell = document.fromFirestore(
          resBody['fields'] as Map<String, Object>,
          resBody['name'] as String,
          resBody['createTime'] as String,
          resBody['updateTime'] as String);
      return LooseResponse.single(shell);
    }
  }

  Future<bool> exists(Documenter document,
      {List<String> idPath = const [],
      bool keepClientOpen = false,
      bool bypassTransaction = false}) async {
    final res = await read(document,
        idPath: idPath,
        ignoreContent: true,
        keepClientOpen: keepClientOpen,
        bypassTransaction: bypassTransaction);
    if (!res.ok || res.errorCode == 404) {
      return false;
    } else {
      return true;
    }
  }

  // UPDATE
  Future<LooseResponse<T, S>> update<T extends DocumentShell<S>, S,
          R extends QueryFields, Q extends QueryField>(
      Documenter<T, S, R> document, List<Q> updateFields,
      {List<String> idPath = const [],
      bool printFields = false,
      bool keepClientOpen = false}) async {
    var workingPath = '${document.location.path}/${document.location.name}';
    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
    if (ancestorCount != idPath.length) {
      throw LooseException(
          '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    _client ??= await _createClient();

    var params = '?currentDocument.exists=true';
    for (final field in updateFields) {
      params = params + '&updateMask.fieldPaths=' + field.name;
    }

    if (_transactionId.isNotEmpty) {
      params = params + '&transaction=' + _transactionId;
    }

    final uri = Uri.https(authority, '${_database.rootPath}${workingPath}');
    final reqBody = document.toFirestoreFields();

    if (printFields) {
      print(json.encode(reqBody));
    }
    final res = await _client.patch(uri, body: json.encode(reqBody));

    if (!keepClientOpen) {
      _client.close();
      _client = null;
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails<T, S>(res.statusCode, res.body);
    }

    final resBody = json.decode(res.body);
    final shell = document.fromFirestore(
        resBody['fields'] as Map<String, Object>,
        resBody['name'] as String,
        resBody['createTime'] as String,
        resBody['updateTime'] as String);
    return LooseResponse.single(shell);
  }

  // DELETE
  Future<LooseResponse<T, S>>
      delete<T extends DocumentShell<S>, S, R extends QueryFields>(
          Documenter<T, S, R> document,
          {List<String> idPath = const [],
          bool keepClientOpen = false}) async {
    var workingPath = '${document.location.path}/${document.location.name}';
    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
    if (ancestorCount != idPath.length) {
      throw LooseException(
          '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    _client ??= await _createClient();

    final queryParameters = <String, String>{};
    // if (_transactionId.isNotEmpty) {
    //   queryParameters.addAll({'transaction': _transactionId});
    // }
    final uri = Uri.https(
        authority, '${_database.rootPath}${workingPath}', queryParameters);
    final res = await _client.post(uri);
    if (!keepClientOpen) {
      _client.close();
      _client = null;
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails<T, S>(res.statusCode, res.body);
    }
    return LooseResponse.single(DocumentShell.empty as T);
  }

  // QUERY
  Future<LooseResponse<T, S>>
      query<T extends DocumentShell<S>, S, R extends QueryFields>(
          Query<T, S, R> query,
          {bool keepClientOpen = false,
          bool bypassTransaction = false}) async {
    final rawBody = query.encode();
    final reqBody = json.encode(rawBody);

    _client ??= await _createClient();

    final queryParameters = <String, String>{};
    if (_transactionId.isNotEmpty && !bypassTransaction) {
      queryParameters.addAll({'transaction': _transactionId});
    }

    final uri = Uri.https(
        authority,
        '${_database.rootPath}${query.document.location.pathToCollection}:runQuery',
        queryParameters);

    final res = await _client.post(uri, body: reqBody);
    if (!keepClientOpen) {
      _client.close();
      _client = null;
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      if (res.statusCode == 400) {
        final resBody = json.decode(res.body) as List<Object>;
        for (final errorObject in resBody) {
          final error = (errorObject as Map<String, Object>)['error']
              as Map<String, Object>;
          if ((error['status'] as String) == 'FAILED_PRECONDITION') {
            throw LooseException((error['message'] as String));
          } else if ((error['status'] as String) == 'INVALID_ARGUMENT') {
            throw LooseException((error['message'] as String));
          }
        }
      }
      return LooseResponse.fail(LooseErrors.apiCallFailed(res.body));
    }

//     [{
//   "error": {
//     "code": 400,
//     "message": "The query requires an index. You can create it here: https://console.firebase.google.com/v1/r/project/dilawri-portal-dev/firestore/indexes?create_composite=Ck9wcm9qZWN0cy9kaWxhd3JpLXBvcnRhbC1kZXYvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZkcHMvaW5kZXhlcy9fEAEaEQoNZGVhbGVyc2hpcFJlZhABGg8KC3N0b2NrTnVtYmVyEAEaCwoHdmVyc2lvbhACGgwKCF9fbmFtZV9fEAI",
//     "status": "FAILED_PRECONDITION"
//   }
// }
// ]

// [{
//   "error": {
//     "code": 400,
//     "message": "inequality filter property and first sort order must be the same: integer and nested.innerString",
//     "status": "INVALID_ARGUMENT"
//   }
// }
// ]

// [{
//   "error": {
//     "code": 400,
//     "message": "order by clause cannot contain a field with an equality filter nested.innerString",
//     "status": "INVALID_ARGUMENT"
//   }
// }

    final decoded = json.decode(res.body);

    // If no object contains 'document', no documents were returned
    if (!((decoded as List)[0] as Map).containsKey('document')) {
      return LooseResponse.list(const []);
    }
    return LooseResponse.list((decoded as List).map((e) {
      final doc = (e as Map)['document'] as Map;

      return query.document.fromFirestore(
          doc['fields'] as Map<String, Object>,
          doc['name'] as String,
          doc['createTime'] as String,
          doc['updateTime'] as String);
    }).toList());
  }

  LooseResponse<T, S> _singleEntityResponseFails<T extends DocumentShell<S>, S>(
      int statusCode, String serverResponse) {
    switch (statusCode) {
      case 409:
        return LooseResponse.fail(LooseErrors.documentExists(serverResponse));
        break;
      case 404:
        return LooseResponse.fail(LooseErrors.notFound(serverResponse));
        break;
      default:
        return LooseResponse.fail(LooseErrors.apiCallFailed(serverResponse));
    }
  }

  Future<String> beginTransaction({bool detached = false}) async {
    if (_transactionId.isNotEmpty && !detached) {
      throw LooseException('A transaction has already been started.');
    }
    _client ??= await _createClient();
    final uri = Uri.https(authority, '${_database.rootPath}:beginTransaction');
    final res = await _client.post(uri);

    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      return '';
    }
    final id =
        (json.decode(res.body) as Map<String, Object>)['transaction'] as String;
    if (!detached) {
      _transactionId = id;
    }
    return id;
  }

  Future<bool> commitTransaction(
      {List<Writable> writes = const [],
      String transactionId = '',
      bool keepClientOpen = false}) async {
    if (_transactionId.isEmpty && transactionId.isEmpty) {
      throw LooseException(
          'A transaction must be started or a transaction id must be provided.');
    }
    _client ??= await _createClient();
    final body = {
      'transaction': transactionId.isNotEmpty ? transactionId : _transactionId,
      'writes': await Future.wait(writes
          .map((e) async => (await e.encode(_database.documentRoot)))
          .toList())
    };
    final uri = Uri.https(authority, '${_database.rootPath}:commit');
    final res = await _client.post(uri, body: json.encode(body));
    if (!keepClientOpen) {
      _client.close();
      _client = null;
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      print(res.statusCode);
      print(res.body);
      return false;
    }
    if (transactionId.isEmpty) {
      _transactionId = '';
    }
    return true;
  }

  Future<bool> rollbackTransaction([String transactionId = '']) async {
    if (_transactionId.isEmpty && transactionId.isEmpty) {
      throw LooseException(
          'There is no current transaction in progress to rollback.');
    }
    _client ??= await _createClient();
    final body = json.encode({
      'transaction': transactionId.isEmpty ? _transactionId : transactionId
    });
    final uri = Uri.https(authority, '${_database.rootPath}:rollback');
    final res = await _client.post(uri, body: body);
    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      print(res.statusCode);
      print(res.body);
      return false;
    }
    _transactionId = '';
    return true;
  }

  Future<BatchWriteResults> batchWrite(List<Writable> writes,
      {bool keepClientOpen = false}) async {
    _client ??= await _createClient();
    final body = {
      'writes': await Future.wait(writes
          .map((e) async => (await e.encode(_database.documentRoot)))
          .toList())
    };
    final uri = Uri.https(authority, '${_database.rootPath}:batchWrite');
    print(uri);
    final res = await _client.post(uri, body: json.encode(body));
    if (!keepClientOpen) {
      _client.close();
      _client = null;
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      print('commit fail');
      print(res.statusCode);
      print(res.body);
      return BatchWriteResults.empty;
    }
    print(res.body);
    final resBody = json.decode(res.body) as Map<String, Object>;
    return BatchWriteResults(writes, resBody);
  }

/////////////////
// batchGet
/////////////////
  Future<BatchGetResults<T, S>>
      batchGet<T extends DocumentShell<S>, S, R extends QueryFields>(
          BatchGetDocuments<T, S, R> documents,
          {bool keepClientOpen = false,
          bool bypassTransaction = false,
          bool ownTransaction = false}) async {
    final documentPaths = <String>[];
    for (final idPath in documents.idPaths) {
      var workingPath =
          '${documents.document.location.path}/${documents.document.location.name}';

      final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
      if (ancestorCount != idPath.length) {
        throw LooseException(
            '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
      }
      for (final id in idPath) {
        workingPath = workingPath.replaceFirst(dynamicNameToken, id);
      }
      documentPaths.add('${_database.documentRoot}${workingPath}');
    }

    final decoded = await batchGetFromPaths(documentPaths,
        ownTransaction: ownTransaction,
        bypassTransaction: bypassTransaction,
        keepClientOpen: keepClientOpen);

    var found = <T>[];
    var missing = <String>[];

    decoded.forEach((e) {
      if ((e as Map<String, Object>).containsKey('found')) {
        final doc = (e as Map<String, Object>)['found'] as Map;
        found.add(documents.document.fromFirestore(
            doc['fields'] as Map<String, Object>,
            doc['name'] as String,
            doc['createTime'] as String,
            doc['updateTime'] as String));
      } else if ((e as Map<String, Object>).containsKey('missing')) {
        missing.add((e as Map<String, Object>)['missing'] as String);
      }
    });

    return BatchGetResults(LooseResponse<T, S>.list(found), missing,
        transactionId: _transactionId);
  }

/////////////////////////
// batchGetFromPaths
/////////////////////////

  Future<List> batchGetFromPaths(List<String> documentPaths,
      {bool ownTransaction = false,
      bool bypassTransaction = false,
      bool keepClientOpen = false}) async {
    final body = <String, Object>{'documents': documentPaths};

    var thisTransactionId = '';

    if (!ownTransaction && !bypassTransaction) {
      body['transaction'] = _transactionId;
      thisTransactionId = _transactionId;
    } else if (ownTransaction) {
      thisTransactionId = await beginTransaction(detached: true);
      body['transaction'] = thisTransactionId;
    }

    _client ??= await _createClient();

    final uri = Uri.https(authority, '${_database.rootPath}:batchGet');

    final res = await _client.post(uri, body: json.encode(body));

    final commit = await commitTransaction(
        transactionId: thisTransactionId, keepClientOpen: keepClientOpen);
    if (!commit) {
      // TODO: Handle batchGet own transaction commit failure
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      print('batchGet fail');
      print(res.statusCode);
      print(res.body);
    }
    return json.decode(res.body) as List;
  }
}

/*
projects/dagobah/databases/(default)/documents/tests/0MN=f9AP0yPfsnQqAQn9
projects/dagobah/databases/(default)/documents/tests/0_keySkO_F_KUYhBwHhy
projects/dagobah/databases/(default)/documents/tests/1Kr1A7rA7A76SffDQvPX
projects/dagobah/databases/(default)/documents/tests/2405P+Y7NFeY=K+007Be
projects/dagobah/databases/(default)/documents/tests/2=dz3xo96g2an69Hn6xX
*/

class BatchGetDocuments<T extends DocumentShell<S>, S, R extends QueryFields> {
  final Documenter<T, S, R> document;
  final List<List<String>> idPaths = [];
  DocumentInfo get location => document.location;
  BatchGetDocuments(this.document);

  void addIdPath(List<String> idPath) {
    idPaths.add(idPath);
  }
}

class BatchGetResults<T extends DocumentShell<S>, S> {
  final LooseResponse<T, S> found;
  final List<String> missing;
  final String transactionId;

  BatchGetResults(this.found, this.missing, {this.transactionId = ''});
}

//   final decoded = json.decode(res.body);

//   // If no object contains 'document', no documents were returned
//   if (!((decoded as List)[0] as Map).containsKey('document')) {
//     return LooseResponse.list(const []);
//   }
//   return LooseResponse.list((decoded as List).map((e) {
//     final doc = (e as Map)['document'] as Map;

//     return query.document.fromFirestore(
//         doc['fields'] as Map<String, Object>,
//         doc['name'] as String,
//         doc['createTime'] as String,
//         doc['updateTime'] as String);
//   }).toList());
// }
