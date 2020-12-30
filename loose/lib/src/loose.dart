import 'dart:convert' show json;
import 'package:googleapis_auth/auth_io.dart' as auth;

import 'package:loose/src/loose_credentials.dart';
import 'package:loose/src/documenter.dart';
import 'package:loose/src/document_shell.dart';
import 'package:loose/src/loose_response.dart';
import 'package:loose/src/reference.dart';
import 'package:loose/src/firestore_database.dart';
import 'package:loose/src/constants.dart';
import 'package:loose/src/write.dart';
import 'package:loose/src/write_results.dart';
import 'package:loose/src/commit_result.dart';
import 'package:loose/src/batch_get_request.dart';
import 'package:loose/src/batch_get_result.dart';
import 'package:loose/src/list_result.dart';
import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/counter.dart';
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

class Transaction {
  final String id;
  final Loose _loose;
  bool complete = false;

  Transaction._(this._loose, this.id);

  static Future<Transaction> newTransaction(Loose loose) async {
    final id = await loose._beginTransaction();
    return Transaction._(loose, id);
  }

  void _checkComplete() {
    if (complete) {
      throw LooseException(
          'The transaction with id "$id" is already complete.');
    }
  }

  Future<LooseEntityResponse<T, S>>
      read<T extends DocumentShell<S>, S, R extends DocumentFields>(
    Documenter<T, S, R> document, {
    List<String> idPath = const [],
  }) async {
    _checkComplete();
    return _loose._readImpl(document,
        idPath: idPath, keepClientOpen: true, transactionId: id);
  }

  Future<bool> exists(Documenter document,
      {List<String> idPath = const []}) async {
    _checkComplete();
    final res = await _loose._readImpl(document,
        idPath: idPath,
        ignoreContent: true,
        keepClientOpen: true,
        transactionId: id);
    if (!res.ok || res.error.isNotFound) {
      return false;
    } else {
      return true;
    }
  }

  Future<ListResults<T, S>>
      list<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Documenter<T, S, R> document,
          {int pageSize = 20,
          String nextPageToken = ''}) async {
    return _loose._listImpl(document,
        keepClientOpen: true, pageSize: pageSize, nextPageToken: nextPageToken);
  }

  Future<LooseListResponse<T, S>>
      query<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Query<T, S, R> query) async {
    _checkComplete();
    return _loose._queryImpl(query, keepClientOpen: true, transactionId: id);
  }

  Future<CommitResult> commit(
      {List<Writable> writes = const [], bool keepClientOpen = false}) async {
    _checkComplete();
    return _loose._commitTransaction(
        writes: writes, transactionId: id, keepClientOpen: keepClientOpen);
  }

  Future<bool> rollback() async {
    return _loose._rollbackTransaction(id);
  }

  Future<int> readCounter(Counter counter) async {
    _checkComplete();
    return _loose._readCounterImpl(counter, transactionId: id);
  }
}

class Loose {
  final _SCOPES = const [cloudPlatformScope, datastoreScope];

  LooseCredentials _creds;
  auth.AutoRefreshingAuthClient _client;
  FirestoreDatabase _database;
  // var _transactionId = '';

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

  Future<Transaction> transaction() async {
    return Transaction.newTransaction(this);
  }

  // CREATE
  Future<LooseEntityResponse<T, S>>
      create<T extends DocumentShell<S>, S, R extends DocumentFields>(
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
    return LooseEntityResponse(shell);
  }

  // READ
  Future<LooseEntityResponse<T, S>>
      _readImpl<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Documenter<T, S, R> document,
          {List<String> idPath = const [],
          bool keepClientOpen = false,
          bool ignoreContent = false,
          String transactionId = ''}) async {
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
    if (transactionId.isNotEmpty) {
      queryParameters.addAll({'transaction': transactionId});
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
      return LooseEntityResponse(shell);
    } else {
      final shell = document.fromFirestore(
          resBody['fields'] as Map<String, Object>,
          resBody['name'] as String,
          resBody['createTime'] as String,
          resBody['updateTime'] as String);
      return LooseEntityResponse(shell);
    }
  }

  Future<LooseEntityResponse<T, S>>
      read<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Documenter<T, S, R> document,
          {List<String> idPath = const [],
          bool keepClientOpen = false}) async {
    return _readImpl(document,
        idPath: idPath, keepClientOpen: keepClientOpen, ignoreContent: false);
  }

  Future<bool> exists(Documenter document,
      {List<String> idPath = const [],
      bool keepClientOpen = false,
      bool bypassTransaction = false}) async {
    final res = await _readImpl(document,
        idPath: idPath, ignoreContent: true, keepClientOpen: keepClientOpen);
    if (!res.ok || res.error.isNotFound) {
      return false;
    } else {
      return true;
    }
  }

  // UPDATE
  Future<LooseEntityResponse<T, S>> update<T extends DocumentShell<S>, S,
          R extends DocumentFields, Q extends QueryField>(
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
    return LooseEntityResponse(shell);
  }

  // DELETE
  Future<LooseEntityResponse<T, S>>
      delete<T extends DocumentShell<S>, S, R extends DocumentFields>(
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
    return LooseEntityResponse(DocumentShell.empty as T);
  }

  // QUERY
  Future<LooseListResponse<T, S>>
      _queryImpl<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Query<T, S, R> query,
          {bool keepClientOpen = false,
          String transactionId = ''}) async {
    final rawBody = query.encode();
    final reqBody = json.encode(rawBody);

    _client ??= await _createClient();

    final queryParameters = <String, String>{};
    if (transactionId.isNotEmpty) {
      queryParameters.addAll({'transaction': transactionId});
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
      return LooseListResponse.fail(LooseErrors.apiCallFailed(res.body));
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
      return LooseListResponse(const []);
    }
    return LooseListResponse((decoded as List).map((e) {
      final doc = (e as Map)['document'] as Map;

      return query.document.fromFirestore(
          doc['fields'] as Map<String, Object>,
          doc['name'] as String,
          doc['createTime'] as String,
          doc['updateTime'] as String);
    }).toList());
  }

  Future<LooseListResponse<T, S>>
      query<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Query<T, S, R> query,
          {bool keepClientOpen = false}) async {
    return _queryImpl(query, keepClientOpen: keepClientOpen);
  }

  LooseEntityResponse<T, S>
      _singleEntityResponseFails<T extends DocumentShell<S>, S>(
          int statusCode, String serverResponse) {
    switch (statusCode) {
      case 409:
        return LooseEntityResponse.fail(
            LooseErrors.documentExists(serverResponse));
        break;
      case 404:
        return LooseEntityResponse.fail(LooseErrors.notFound(serverResponse));
        break;
      default:
        return LooseEntityResponse.fail(
            LooseErrors.apiCallFailed(serverResponse));
    }
  }

  // TRANSACTIONS
  Future<String> _beginTransaction() async {
    _client ??= await _createClient();
    final uri = Uri.https(authority, '${_database.rootPath}:beginTransaction');
    final res = await _client.post(uri);

    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      return '';
    }
    final id =
        (json.decode(res.body) as Map<String, Object>)['transaction'] as String;
    return id;
  }

  Future<CommitResult> _commitTransaction(
      {List<Writable> writes = const [],
      String transactionId = '',
      bool keepClientOpen = false}) async {
    _client ??= await _createClient();
    final body = {
      'transaction': transactionId,
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
      return CommitResult(WriteResults.empty, '');
    }
    final resBody = json.decode(res.body) as Map<String, Object>;
    return CommitResult(
        WriteResults(writes, resBody), resBody['commitTime'] as String);
  }

  Future<bool> _rollbackTransaction(String transactionId) async {
    _client ??= await _createClient();
    final body = json.encode({'transaction': transactionId});
    final uri = Uri.https(authority, '${_database.rootPath}:rollback');
    final res = await _client.post(uri, body: body);
    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      print(res.statusCode);
      print(res.body);
      return false;
    }
    return true;
  }

  // BATCH WRITE
  Future<WriteResults> batchWrite(List<Writable> writes,
      {bool keepClientOpen = false}) async {
    _client ??= await _createClient();
    final body = {
      'writes': await Future.wait(writes
          .map((e) async => (await e.encode(_database.documentRoot)))
          .toList())
    };
    final uri = Uri.https(authority, '${_database.rootPath}:batchWrite');
    final res = await _client.post(uri, body: json.encode(body));
    if (!keepClientOpen) {
      _client.close();
      _client = null;
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      return WriteResults.empty;
    }
    final resBody = json.decode(res.body) as Map<String, Object>;
    return WriteResults(writes, resBody);
  }

  // BATCH GET
  Future<BatchGetResults<T, S>>
      _batchGetImpl<T extends DocumentShell<S>, S, R extends DocumentFields>(
          BatchGetRequest<T, S, R> documents,
          {bool keepClientOpen = false,
          String transactionId = ''}) async {
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

    final decoded = await _batchGetFromPaths(documentPaths,
        transactionId: transactionId, keepClientOpen: keepClientOpen);

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

    return BatchGetResults(LooseListResponse(found), missing);
  }

  // BATCH GET FROM PATHS
  Future<List> _batchGetFromPaths(List<String> documentPaths,
      {String transactionId = '',
      bool keepClientOpen = false,
      bool ownTransaction = false}) async {
    final body = <String, Object>{'documents': documentPaths};

    var ownTransactionId = '';
    if (transactionId.isNotEmpty) {
      body['transaction'] = transactionId;
    } else if (ownTransaction) {
      ownTransactionId = await _beginTransaction();
      body['transaction'] = ownTransactionId;
    }

    _client ??= await _createClient();

    final uri = Uri.https(authority, '${_database.rootPath}:batchGet');

    final res = await _client.post(uri, body: json.encode(body));

    if (ownTransactionId.isNotEmpty) {
      final commit = await _commitTransaction(
          transactionId: ownTransactionId, keepClientOpen: keepClientOpen);
      if (!commit.ok) {
        // TODO: Handle batchGet own transaction commit failure
      }
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      print('batchGet fail');
      print(res.statusCode);
      print(res.body);
    }
    return json.decode(res.body) as List;
  }

  // READ COUNTER
  Future<int> _readCounterImpl(Counter counter,
      {String transactionId = ''}) async {
    final shards = await _listFromPath(counter.location,
        pageSize: 1000,
        keepClientOpen: hasOpenClient,
        transactionId: transactionId,
        ownTransaction: transactionId.isEmpty);

    var result = 0;

    ((shards as Map<String, Object>)['documents'] as List).forEach((e) {
      final fields = (e as Map<String, Object>)['fields'];
      final field = (fields as Map<String, Object>)[counter.fieldPath];
      final value = int.tryParse(
          (field as Map<String, Object>)['integerValue'] as String);
      if (value == null) {
        return null;
      } else {
        result = result + value;
      }
    });
    return result;
  }

  Future<int> readCounter(Counter counter) async {
    return _readCounterImpl(counter);
  }

  // WRITE COUNTER
  Future writeCounter(Shard shard) async {
    final write = Write.count(shard);

    await batchWrite([write], keepClientOpen: hasOpenClient);
  }

  // LIST GET
  Future<ListResults<T, S>>
      _listImpl<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Documenter<T, S, R> document,
          {int pageSize = 0,
          String nextPageToken = '',
          bool keepClientOpen = false,
          String transactionId = ''}) async {
    var workingPath =
        '${document.location.pathToCollection}${document.location.collection}';

    final decoded = await _listFromPath(workingPath,
        pageSize: pageSize,
        nextPageToken: nextPageToken,
        transactionId: transactionId,
        keepClientOpen: keepClientOpen);

    var docs = <T>[];
    var resultNextPageToken = '';

    ((decoded as Map<String, Object>)['documents'] as List).forEach((e) {
      final doc = e as Map<String, Object>;
      docs.add(document.fromFirestore(
          doc['fields'] as Map<String, Object>,
          doc['name'] as String,
          doc['createTime'] as String,
          doc['updateTime'] as String));
    });
    resultNextPageToken =
        ((decoded as Map<String, Object>)['nextPageToken'] ?? '') as String;

    return ListResults(LooseListResponse(docs), resultNextPageToken);
  }

  // LIST FROM PATH
  Future<Map> _listFromPath(String collectionPath,
      {String transactionId = '',
      bool keepClientOpen = false,
      int pageSize = 20,
      String nextPageToken = '',
      bool ownTransaction = false}) async {
    final params = <String, String>{};

    params['pageSize'] = pageSize.toString();

    if (nextPageToken.isNotEmpty) {
      params['nextPageToken'] = nextPageToken;
    }

    var ownTransactionId = '';
    if (transactionId.isNotEmpty) {
      params['transaction'] = transactionId;
    } else if (ownTransaction) {
      ownTransactionId = await _beginTransaction();
      params['transaction'] = ownTransactionId;
    }

    _client ??= await _createClient();

    final uri =
        Uri.https(authority, '${_database.rootPath}$collectionPath', params);

    final res = await _client.get(uri);

    if (ownTransactionId.isNotEmpty) {
      final commit = await _commitTransaction(
          transactionId: ownTransactionId, keepClientOpen: keepClientOpen);
      if (!commit.ok) {
        // TODO: Handle batchGet own transaction commit failure
      }
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      print('batchGet fail');
      print(res.statusCode);
      print(res.body);
    }
    return json.decode(res.body) as Map;
  }

  Future<ListResults<T, S>>
      list<T extends DocumentShell<S>, S, R extends DocumentFields>(
          Documenter<T, S, R> document,
          {int pageSize = 20,
          String nextPageToken = '',
          bool keepClientOpen = false}) async {
    return _listImpl(document,
        pageSize: pageSize,
        nextPageToken: nextPageToken,
        keepClientOpen: keepClientOpen);
  }
}
