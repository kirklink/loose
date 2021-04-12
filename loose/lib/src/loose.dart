import 'dart:convert' show json;
import 'package:googleapis_auth/auth_io.dart' as auth;

import './loose_credentials.dart';

import 'document_response.dart';
import 'document_request.dart';
import 'loose_response/loose_response.dart';
import 'reference.dart';
import 'firestore_database.dart';
import 'constants.dart';
import 'write/write_results.dart';
import 'loose_response/list_result.dart';
import 'loose_response/commit_result.dart';
import 'loose_exception.dart';
import 'write/write.dart';
import 'counter.dart';
import 'query/query.dart';
import 'document_field.dart';
import 'batch_get_request.dart';
import 'loose_response/batch_get_result.dart';

abstract class LooseErrors {
  static LooseError documentExists(String serverMessage) =>
      LooseError(409, 'Document already exists', serverMessage);
  static LooseError notFound(String serverMessage) =>
      LooseError(404, 'Document not found', serverMessage);
  static LooseError apiCallFailed(String serverMessage) =>
      LooseError(500, 'Call to Firestore failed.', serverMessage);
}

class _TransactionDocumentHandler<T, Q extends DocumentField> {
  final DocumentRequest<T> _request;
  final Transaction _transaction;
  const _TransactionDocumentHandler(this._transaction, this._request);

  Future<LooseEntityResponse<T>> read(
      {List<String> idPath = const [], bool keepClientOpen = false}) async {
    return _transaction._read(_request, idPath: idPath);
  }

  Future<bool> exists(
      {List<String> idPath = const [], bool keepClientOpen = false}) async {
    return _transaction._exists(_request, idPath: idPath);
  }
}

class Transaction {
  final String id;
  final Loose _loose;
  bool complete = false;

  Transaction._(this._loose, this.id);

  // static Future<Transaction> newTransaction(Loose loose) async {
  //   final id = await loose._beginTransaction();
  //   return Transaction._(loose, id);
  // }

  void _checkComplete() {
    if (complete) {
      throw LooseException(
          'The transaction with id "$id" is already complete.');
    }
  }

  _TransactionDocumentHandler<T, Q> document<T, Q extends DocumentField>(
      DocumentRequest<T> request) {
    return _TransactionDocumentHandler(this, request);
  }

  Future<LooseEntityResponse<T>> _read<T>(
    DocumentRequest<T> request, {
    List<String> idPath = const [],
  }) async {
    _checkComplete();
    return _loose._readImpl(request,
        idPath: idPath, keepClientOpen: true, transactionId: id);
  }

  Future<bool> _exists<T>(DocumentRequest<T> request,
      {List<String> idPath = const []}) async {
    _checkComplete();
    final res = await _loose._readImpl(request,
        idPath: idPath,
        ignoreContent: true,
        keepClientOpen: true,
        transactionId: id);
    if (res.ok) {
      return true;
    } else if (res.error.isNotFound) {
      return false;
    } else {
      throw LooseException('Check for document failed.');
    }
  }

  Future<ListResults<T>> list<T>(DocumentRequest<T> document,
      {List<String> idPath = const [],
      int pageSize = 20,
      String nextPageToken = ''}) async {
    return _loose._listImpl(document,
        idPath: idPath,
        transactionId: id,
        keepClientOpen: true,
        pageSize: pageSize,
        nextPageToken: nextPageToken);
  }

  Future<BatchGetResults> batchGet<T>(
      BatchGetRequest<T> batchGetRequest) async {
    return _loose._batchGetImpl(batchGetRequest,
        keepClientOpen: true, transactionId: id);
  }

  Future<LooseListResponse<T>> query<T>(Query<T> query) async {
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

  TransactionCountHandler counter(Counter counter,
      {List<String> idPath = const []}) {
    _checkComplete();
    return TransactionCountHandler(_loose, counter, idPath, id);
  }
}

class Loose {
  final _SCOPES = const [cloudPlatformScope, datastoreScope];

  // LooseCredentials _credentials;
  auth.AutoRefreshingAuthClient _client;

  String get documentRoot => _database.documentRoot;
  String get databaseRoot => _database.rootPath;
  bool get hasOpenClient => _client != null;

  Loose._();

  factory Loose() {
    if (_credentials == null || _database == null) {
      throw LooseException('Loose has not been initialized with Loose.init()');
    }
    return Loose._();
  }

  factory Loose.init(LooseCredentials credentials, FirestoreDatabase database) {
    if (_credentials != null || _database != null) {
      throw LooseException('Loose has already been initialized.');
    }
    _credentials ??= credentials;
    _database ??= database;
    return Loose._();
  }

  // static Loose _cache;
  static LooseCredentials _credentials;
  static FirestoreDatabase _database;

  Future<auth.AutoRefreshingAuthClient> _createClient() async {
    if (_credentials.fromApplicationDefault) {
      return auth.clientViaApplicationDefaultCredentials(scopes: _SCOPES);
    } else {
      final jsonCreds = auth.ServiceAccountCredentials.fromJson({
        'private_key_id': _credentials.privateKeyId,
        'private_key': _credentials.privateKey,
        'client_email': _credentials.clientEmail,
        'client_id': _credentials.clientId,
        'type': _credentials.type
      });
      return auth.clientViaServiceAccount(jsonCreds, _SCOPES);
    }
  }

  Reference reference(DocumentRequest request,
      {List<String> idPath = const []}) {
    return Reference(request, _database, idPath: idPath);
  }

  void done() {
    if (_client != null) {
      _client.close();
      _client = null;
    }
  }

  Future<Transaction> transaction() async {
    final id = await _beginTransaction();
    if (id.isEmpty) {
      throw LooseException('Could not initiate a transaction.');
    }
    return Transaction._(this, id);
  }

  DocumentHandler<T, Q> document<T, Q extends DocumentField>(
      DocumentRequest<T> request) {
    return DocumentHandler(this, request);
  }

  CountHandler counter(Counter counter, {List<String> idPath = const []}) {
    return CountHandler(this, counter, idPath);
  }

  // CREATE
  Future<LooseEntityResponse<T>> _create<T>(
      DocumentRequest<T> request, T entity,
      {List<String> idPath = const [],
      bool autoAssignId = false,
      bool printFields = false,
      bool keepClientOpen = false}) async {
    var workingPath = request.document.resolvePath(idPath, autoAssignId);

    var docId = '';
    if (autoAssignId) {
      workingPath = workingPath.replaceFirst('/' + dynamicNameToken, '');
    } else {
      final split = workingPath.split('/');
      docId = split.removeLast();
      workingPath = split.join('/');
    }

    _client ??= await _createClient();

    final queryParameters = <String, String>{};
    if (docId.isNotEmpty) {
      queryParameters.addAll({'documentId': docId});
    }

    final uri = Uri.https(
        authority, '${_database.rootPath}$workingPath', queryParameters);

    final reqBody = request.toFirestore(entity);
    if (printFields) {
      print(json.encode(reqBody));
    }
    final res = await _client.post(uri, body: json.encode(reqBody));

    if (!keepClientOpen) {
      done();
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails<T>(res.statusCode, res.body);
    }

    final resBody = json.decode(res.body) as Map<String, Object>;

    final response = request.fromFirestore(resBody);
    return LooseEntityResponse(response);
  }

  // READ
  Future<LooseEntityResponse<T>> _readImpl<T>(DocumentRequest<T> request,
      {List<String> idPath = const [],
      bool keepClientOpen = false,
      bool ignoreContent = false,
      String transactionId = ''}) async {
    final workingPath = request.document.resolvePath(idPath);

    _client ??= await _createClient();

    final queryParameters = <String, String>{};
    if (transactionId.isNotEmpty) {
      queryParameters.addAll({'transaction': transactionId});
    }

    final uri = Uri.https(
        authority, '${_database.rootPath}$workingPath', queryParameters);
    final res = await _client.get(uri);

    if (!keepClientOpen) {
      done();
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails(res.statusCode, res.body);
    }

    if (ignoreContent) {
      final response = DocumentResponse.empty as DocumentResponse<T>;
      return LooseEntityResponse(response);
    } else {
      final resBody = json.decode(res.body) as Map<String, Object>;
      final response = request.fromFirestore(resBody);
      return LooseEntityResponse(response);
    }
  }

  Future<LooseEntityResponse<T>> _read<T>(DocumentRequest<T> request,
      {List<String> idPath = const [], bool keepClientOpen = false}) async {
    return _readImpl(request,
        idPath: idPath, keepClientOpen: keepClientOpen, ignoreContent: false);
  }

  Future<bool> exists<T>(DocumentRequest<T> request,
      {List<String> idPath = const [], bool keepClientOpen = false}) async {
    final res = await _readImpl(request,
        idPath: idPath, ignoreContent: true, keepClientOpen: keepClientOpen);
    if (res.ok) {
      return true;
    } else if (res.error.isNotFound) {
      return false;
    } else {
      throw LooseException('Check for document failed.');
    }
  }

  // UPDATE
  Future<LooseEntityResponse<T>> _update<T, Q extends DocumentField>(
      DocumentRequest<T> request, T entity, List<Q> updateFields,
      {List<String> idPath = const [],
      bool printFields = false,
      bool keepClientOpen = false}) async {
    final workingPath = request.document.resolvePath(idPath);

    _client ??= await _createClient();

    final params = <String, dynamic>{};
    params['updateMask.fieldPaths'] =
        updateFields.map((e) => e.name).toList(growable: false);
    params['currentDocument.exists'] = 'true';

    final uri = Uri(
        scheme: 'https',
        host: authority,
        path: '${_database.rootPath}$workingPath',
        queryParameters: params);
    final reqBody = request.toFirestore(entity);

    if (printFields) {
      print(json.encode(reqBody));
    }
    final res = await _client.patch(uri, body: json.encode(reqBody));

    if (!keepClientOpen) {
      done();
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails<T>(res.statusCode, res.body);
    }

    final resBody = json.decode(res.body) as Map<String, Object>;
    final response = request.fromFirestore(resBody);
    return LooseEntityResponse(response);
  }

  // DELETE
  Future<LooseEntityResponse<T>> _delete<T>(DocumentRequest<T> request,
      {List<String> idPath = const [], bool keepClientOpen = false}) async {
    final workingPath = request.document.resolvePath(idPath);

    _client ??= await _createClient();

    final queryParameters = <String, String>{};

    final uri = Uri.https(
        authority, '${_database.rootPath}$workingPath', queryParameters);
    final res = await _client.delete(uri);
    if (!keepClientOpen) {
      done();
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails<T>(res.statusCode, res.body);
    }
    return LooseEntityResponse(DocumentResponse.empty as DocumentResponse<T>);
  }

  // QUERY
  Future<LooseListResponse<T>> _queryImpl<T>(Query<T> query,
      {bool keepClientOpen = false, String transactionId = ''}) async {
    final rawBody = query.encode();

    _client ??= await _createClient();

    if (transactionId.isNotEmpty) {
      rawBody['transaction'] = transactionId;
    }

    final reqBody = json.encode(rawBody);

    final path = query.location;

    final uri = Uri.https(authority, '${_database.rootPath}$path:runQuery');

    final res = await _client.post(uri, body: reqBody);

    if (!keepClientOpen) {
      done();
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      if (res.statusCode == 400) {
        final resBody = json.decode(res.body) as List<Object>;
        for (final errorObject in resBody) {
          final error = (errorObject as Map<String, Object>)['error']
              as Map<String, Object>;
          if ((error['status'] as String) == 'FAILED_PRECONDITION') {
            throw LooseException(
                'SERVER ERROR [${error['status'] as String}]: ${(error['message'] as String)}');
          } else if ((error['status'] as String) == 'INVALID_ARGUMENT') {
            throw LooseException(
                'SERVER ERROR [${error['status'] as String}]: ${(error['message'] as String)}');
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

    final docs = <DocumentResponse<T>>[];

    (decoded as List).forEach((e) {
      final doc = (e as Map<String, Object>)['document'] as Map<String, Object>;
      docs.add(query.request.fromFirestore(doc));
    });

    return LooseListResponse(docs);
  }

  Future<LooseListResponse<T>> query<T>(Query<T> query,
      {bool keepClientOpen = false}) async {
    return _queryImpl(query, keepClientOpen: keepClientOpen);
  }

  LooseEntityResponse<T> _singleEntityResponseFails<T>(
      int statusCode, String serverResponse) {
    switch (statusCode) {
      case 409:
        return LooseEntityResponse.fail(
            LooseErrors.documentExists(serverResponse),
            DocumentResponse.empty as DocumentResponse<T>);
        break;
      case 404:
        return LooseEntityResponse.fail(LooseErrors.notFound(serverResponse),
            DocumentResponse.empty as DocumentResponse<T>);
        break;
      default:
        return LooseEntityResponse.fail(
            LooseErrors.apiCallFailed(serverResponse),
            DocumentResponse.empty as DocumentResponse<T>);
    }
  }

//   // TRANSACTIONS
  Future<String> _beginTransaction() async {
    _client ??= await _createClient();
    final uri = Uri.https(authority, '${_database.rootPath}:beginTransaction');
    final res = await _client.post(uri);

    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      return '';
    }
    final id = (json.decode(res.body) as Map<String, Object>)['transaction']
            as String ??
        '';
    return id;
  }

  Future<CommitResult> _commitTransaction(
      {List<Writable> writes = const [],
      String transactionId = '',
      bool keepClientOpen = false}) async {
    if (writes.length > 500) {
      throw LooseException('Only 500 writes allowed per request.');
    }
    _client ??= await _createClient();
    final body = {
      'transaction': transactionId,
      'writes': writes.map((e) => e.write(this)).toList()
    };
    final uri = Uri.https(authority, '${_database.rootPath}:commit');
    final res = await _client.post(uri, body: json.encode(body));
    if (!keepClientOpen) {
      done();
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      print(res.statusCode);
      print(res.body);
      return CommitResult(WriteResults.empty, '');
    }
    final resBody = json.decode(res.body) as Map<String, Object>;
    return CommitResult(
        WriteResults(writes, resBody), resBody['commitTime'] as String ?? '');
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
    final docNames = <String>[];
    final body = {
      'writes': writes.map((e) {
        if (docNames.contains(e.name)) {
          throw LooseException(
              'The same document cannot be written more than once in a single request.');
        }
        docNames.add(e.name);
        return e.write(this);
      }).toList()
    };
    // print(body);
    final uri = Uri.https(authority, '${_database.rootPath}:batchWrite');
    final res = await _client.post(uri, body: json.encode(body));
    if (!keepClientOpen) {
      done();
    }
    // print(res.statusCode);
    // print(res.body);
    if (res.statusCode < 200 || res.statusCode > 299) {
      // TODO: Handle failed transaction
      return WriteResults.empty;
    }
    final resBody = json.decode(res.body) as Map<String, Object>;
    return WriteResults(writes, resBody);
  }

  // BATCH GET
  Future<BatchGetResults> batchGet<T>(BatchGetRequest<T> batchGetRequest,
      {bool keepClientOpen = false}) async {
    return _batchGetImpl(batchGetRequest, keepClientOpen: keepClientOpen);
  }

  Future<BatchGetResults> _batchGetImpl<T>(BatchGetRequest<T> batchGetRequest,
      {bool keepClientOpen = false, String transactionId = ''}) async {
    final docs = <String, DocumentRequest<T>>{};

    batchGetRequest.documents.keys.forEach((key) {
      docs['${_database.documentRoot}$key'] = batchGetRequest.documents[key];
    });

    final decoded = await _batchGetFromPaths(docs.keys.toList(),
        transactionId: transactionId, keepClientOpen: keepClientOpen);

    var found = <DocumentResponse<T>>[];
    var missing = <String>[];

    decoded.forEach((e) {
      if ((e as Map<String, Object>).containsKey('found')) {
        final doc = (e as Map<String, Object>)['found'] as Map<String, Object>;
        final name = doc['name'] as String;
        final request = docs[name];
        found.add(request.fromFirestore(doc));
      } else if ((e as Map<String, Object>).containsKey('missing')) {
        missing.add((e as Map<String, Object>)['missing'] as String ?? '');
      }
    });

    return BatchGetResults(found, missing);
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
      {List<String> idPath = const [],
      String transactionId = '',
      bool keepClientOpen = false}) async {
    var nextPageToken = '';
    var result = 0;
    do {
      final shards = await _listFromPath(counter.path,
          idPath: idPath,
          pageSize: 10,
          keepClientOpen: keepClientOpen,
          transactionId: transactionId,
          ownTransaction: transactionId.isEmpty,
          nextPageToken: nextPageToken);

      ((shards as Map<String, Object>)['documents'] as List).forEach((e) {
        final fields =
            ((e as Map<String, Object>)['fields']) as Map<String, Object>;
        final field = (fields)[Counter.counterFieldName];
        final value = int.tryParse(
            (field as Map<String, Object>)['integerValue'] as String);
        if (value == null) {
          return null;
        } else {
          result += value;
        }
      });
      nextPageToken =
          (shards as Map<String, Object>)['nextPageToken'] as String ?? '';
    } while (nextPageToken.isNotEmpty);

    return result;
  }

  // LIST GET
  Future<ListResults<T>> _listImpl<T>(DocumentRequest<T> request,
      {List<String> idPath = const [],
      int pageSize = 20,
      String nextPageToken = '',
      bool keepClientOpen = false,
      String transactionId = ''}) async {
    final decoded = await _listFromPath('${request.document.parent.path}',
        idPath: idPath,
        pageSize: pageSize,
        nextPageToken: nextPageToken,
        transactionId: transactionId,
        keepClientOpen: keepClientOpen);

    final docs = <DocumentResponse<T>>[];
    var resultNextPageToken = '';

    ((decoded as Map<String, Object>)['documents'] as List).forEach((e) {
      final doc = e as Map<String, Object>;
      docs.add(request.fromFirestore(doc));
    });
    resultNextPageToken =
        ((decoded as Map<String, Object>)['nextPageToken'] ?? '') as String;

    return ListResults(docs, resultNextPageToken);
  }

  // LIST FROM PATH
  Future<Map> _listFromPath(String collectionPath,
      {List<String> idPath = const [],
      String transactionId = '',
      bool keepClientOpen = false,
      int pageSize = 20,
      String nextPageToken = '',
      bool ownTransaction = false}) async {
    final tokenCount = dynamicNameToken.allMatches(collectionPath).length;
    if (tokenCount != idPath.length) {
      throw LooseException(
          '${idPath.length} ids provided and $tokenCount are required.');
    }
    var workingPath = '$collectionPath';

    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    final params = <String, String>{};

    params['pageSize'] = pageSize.toString();

    if (nextPageToken.isNotEmpty) {
      params['pageToken'] = nextPageToken;
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
        Uri.https(authority, '${_database.rootPath}$workingPath', params);

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
      print(res.statusCode);
      print(res.body);
    }
    return json.decode(res.body) as Map;
  }

  Future<ListResults<T>> list<T>(DocumentRequest<T> request,
      {List<String> idPath = const [],
      int pageSize = 20,
      String nextPageToken = '',
      bool keepClientOpen = false}) async {
    return _listImpl(request,
        idPath: idPath,
        pageSize: pageSize,
        nextPageToken: nextPageToken,
        keepClientOpen: keepClientOpen);
  }
}

class CountHandler {
  final Loose _loose;
  final Counter _counter;
  final List<String> _idPath;

  CountHandler(this._loose, this._counter, this._idPath);

  Future<bool> increase({int by = 1, bool keepClientOpen = false}) async {
    final write = WriteCounter(_counter, by, _idPath, '');
    final r = await _loose.batchWrite([write], keepClientOpen: keepClientOpen);
    return !r.hasErrors;
  }

  Future<bool> decrease({int by = 1, bool keepClientOpen = false}) async {
    final write = WriteCounter(_counter, by * -1, _idPath, '');
    final r = await _loose.batchWrite([write], keepClientOpen: keepClientOpen);
    return !r.hasErrors;
  }

  Future<int> read({bool keepClientOpen = false}) async {
    return _loose._readCounterImpl(_counter, keepClientOpen: keepClientOpen);
  }
}

class TransactionCountHandler {
  final Loose _loose;
  final Counter _counter;
  final List<String> _idPath;
  final String _transactionId;

  TransactionCountHandler(
      this._loose, this._counter, this._idPath, this._transactionId);

  Future<int> read() async {
    return _loose._readCounterImpl(_counter,
        idPath: _idPath, transactionId: _transactionId, keepClientOpen: true);
  }
}

class DocumentHandler<T, Q extends DocumentField> {
  final DocumentRequest<T> _request;
  final Loose _loose;
  const DocumentHandler(this._loose, this._request);

  Future<LooseEntityResponse<T>> create(T entity,
      {bool autoAssignId = false,
      List<String> idPath = const [],
      bool printFields = false,
      bool keepClientOpen = false}) async {
    return _loose._create(_request, entity,
        idPath: idPath,
        autoAssignId: autoAssignId,
        printFields: printFields,
        keepClientOpen: keepClientOpen);
  }

  Future<LooseEntityResponse<T>> read(
      {List<String> idPath = const [], bool keepClientOpen = false}) async {
    return _loose._read(_request,
        idPath: idPath, keepClientOpen: keepClientOpen);
  }

  Future<LooseEntityResponse<T>> update(T entity, List<Q> fields,
      {List<String> idPath = const [],
      bool printFields = false,
      bool keepClientOpen = false}) async {
    return _loose._update(_request, entity, fields,
        idPath: idPath,
        printFields: printFields,
        keepClientOpen: keepClientOpen);
  }

  Future<LooseEntityResponse<T>> delete(
      {List<String> idPath = const [], bool keepClientOpen = false}) async {
    return _loose._delete(_request,
        idPath: idPath, keepClientOpen: keepClientOpen);
  }

  Future<LooseEntityResponse<T>> updateOrCreate(T entity, List<Q> fields,
      {List<String> idPath = const [],
      bool autoAssignId = false,
      bool printFields = false,
      bool keepClientOpen = false}) async {
    final updateRes = await _loose._update(_request, entity, fields,
        idPath: idPath,
        printFields: printFields,
        keepClientOpen: keepClientOpen);
    if (updateRes.ok) {
      return updateRes;
    } else {
      final c = _loose._create(_request, entity,
          idPath: idPath,
          autoAssignId: autoAssignId,
          printFields: printFields,
          keepClientOpen: keepClientOpen);
      return c;
    }
  }
}
