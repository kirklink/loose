import 'dart:convert' show json;
import 'package:googleapis_auth/auth_io.dart' as auth;

import './loose_credentials.dart';
// import 'documenter.dart';
import 'document.dart';
import 'document_response.dart';
import 'document_request.dart';
import 'loose_response.dart';
import 'reference.dart';
import 'firestore_database.dart';
import 'constants.dart';
// import 'write.dart';
// import 'write_results.dart';
// import 'commit_result.dart';
// import 'batch_get_request.dart';
// import 'batch_get_result.dart';
// import 'list_result.dart';
import 'loose_exception.dart';
// import 'counter.dart';
// import 'query/query.dart';
// import 'query/query_field.dart';

abstract class LooseErrors {
  static LooseError documentExists(String serverMessage) =>
      LooseError(409, 'Document already exists', serverMessage);
  static LooseError notFound(String serverMessage) =>
      LooseError(404, 'Document not found', serverMessage);
  static LooseError apiCallFailed(String serverMessage) =>
      LooseError(500, 'Call to Firestore failed.', serverMessage);
}

// class Transaction {
//   final String id;
//   final Loose _loose;
//   bool complete = false;

//   Transaction._(this._loose, this.id);

//   static Future<Transaction> newTransaction(Loose loose) async {
//     final id = await loose._beginTransaction();
//     return Transaction._(loose, id);
//   }

//   void _checkComplete() {
//     if (complete) {
//       throw LooseException(
//           'The transaction with id "$id" is already complete.');
//     }
//   }

//   Future<LooseEntityResponse> read<DocumentRequest>(
//     DocumentRequest request, {
//     List<String> idPath = const [],
//   }) async {
//     _checkComplete();
//     return _loose._readImpl(request,
//         idPath: idPath, keepClientOpen: true, transactionId: id);
//   }

//   Future<bool> exists(Documenter document,
//       {List<String> idPath = const []}) async {
//     _checkComplete();
//     final res = await _loose._readImpl(document,
//         idPath: idPath,
//         ignoreContent: true,
//         keepClientOpen: true,
//         transactionId: id);
//     if (!res.ok || res.error.isNotFound) {
//       return false;
//     } else {
//       return true;
//     }
//   }

//   Future<ListResults<T, S>>
//       list<T extends DocumentResponse<S>, S, R extends DocumentFields>(
//           Documenter<T, S, R> document,
//           {int pageSize = 20,
//           String nextPageToken = ''}) async {
//     return _loose._listImpl(document,
//         keepClientOpen: true, pageSize: pageSize, nextPageToken: nextPageToken);
//   }

//   Future<LooseListResponse<T, S>>
//       query<T extends DocumentResponse<S>, S, R extends DocumentFields>(
//           Query<T, S, R> query) async {
//     _checkComplete();
//     return _loose._queryImpl(query, keepClientOpen: true, transactionId: id);
//   }

//   Future<CommitResult> commit(
//       {List<Writable> writes = const [], bool keepClientOpen = false}) async {
//     _checkComplete();
//     return _loose._commitTransaction(
//         writes: writes, transactionId: id, keepClientOpen: keepClientOpen);
//   }

//   Future<bool> rollback() async {
//     return _loose._rollbackTransaction(id);
//   }

//   Future<int> readCounter(Counter counter) async {
//     _checkComplete();
//     return _loose._readCounterImpl(counter, transactionId: id);
//   }
// }

class Loose {
  final _SCOPES = const [cloudPlatformScope, datastoreScope];

  LooseCredentials _creds;
  auth.AutoRefreshingAuthClient _client;
  // FirestoreDatabase _database;
  // var _transactionId = '';

  String get documentRoot => _database.documentRoot;
  String get databaseRoot => _database.rootPath;
  bool get hasOpenClient => _client != null;

  Loose._(LooseCredentials credentials, FirestoreDatabase database) {
    _creds = credentials;
    _database = database;
  }

  factory Loose() {
    if (_credentials == null || _database == null) {
      throw LooseException('Loose has not been initialized with Loose.init()');
    }
    return Loose._(_credentials, _database);
  }

  static void init(LooseCredentials credentials, FirestoreDatabase database) {
    if (_credentials != null || _database != null) {
      throw LooseException('Loose has already been initialized.');
    }
    _credentials ??= credentials;
    _database ??= database;
  }

  // static Loose _cache;
  static LooseCredentials _credentials;
  static FirestoreDatabase _database;

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

  Reference reference(Document document, {List<String> idPath = const []}) {
    return Reference(document, _database, idPath: idPath);
  }

  void done() {
    if (_client != null) {
      _client.close();
      _client = null;
    }
  }

  // Future<Transaction> transaction() async {
  //   return Transaction.newTransaction(this);
  // }

  // CREATE
  Future<LooseEntityResponse<T>> create<T>(DocumentRequest<T> loose, T entity,
      {List<String> idPath = const [],
      bool autoAssignId = false,
      bool printFields = false,
      bool keepClientOpen = false}) async {
    final tokenCount = dynamicNameToken.allMatches(loose.document.path).length;
    var idCount = autoAssignId ? idPath.length + 1 : idPath.length;

    if (tokenCount != idCount) {
      throw LooseException(
          '$idCount ids provided and $tokenCount are required.');
    }

    var workingPath = loose.document.path;
    var docId = '';
    if (workingPath.endsWith(dynamicNameToken) && !autoAssignId) {
      docId == idPath.removeLast();
    }

    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    if (autoAssignId) {
      workingPath = workingPath.replaceFirst('/' + dynamicNameToken, '');
    }

    print(docId);
    print(workingPath);

    _client ??= await _createClient();

    final queryParameters = <String, String>{};
    // if (_transactionId.isNotEmpty) {
    //   queryParameters.addAll({'transaction': _transactionId});
    // }
    if (docId.isNotEmpty) {
      queryParameters.addAll({'documentId': docId});
    }

    print('${_database.rootPath}${workingPath}');
    final uri = Uri.https(
        authority, '${_database.rootPath}${workingPath}', queryParameters);

    final reqBody = loose.toFirestore(entity);
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

    final response = loose.fromFirestore(resBody);
    return LooseEntityResponse(response);
  }

  // READ
  Future<LooseEntityResponse<T>> _readImpl<T>(DocumentRequest<T> request,
      {List<String> idPath = const [],
      bool keepClientOpen = false,
      bool ignoreContent = false,
      String transactionId = ''}) async {
    var workingPath = '${request.document.path}';

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
      done();
    }

    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails(res.statusCode, res.body);
    }

    if (ignoreContent) {
      final response = DocumentResponse.empty<T>();
      return LooseEntityResponse(response);
    } else {
      final resBody = json.decode(res.body) as Map<String, Object>;
      final response = request.fromFirestore(resBody);
      return LooseEntityResponse(response);
    }
  }

  Future<LooseEntityResponse<T>> read<T>(DocumentRequest<T> request,
      {List<String> idPath = const [], bool keepClientOpen = false}) async {
    return _readImpl(request,
        idPath: idPath, keepClientOpen: keepClientOpen, ignoreContent: false);
  }

  Future<bool> exists<T>(DocumentRequest<T> request,
      {List<String> idPath = const [], bool keepClientOpen = false}) async {
    final res = await _readImpl(request,
        idPath: idPath, ignoreContent: true, keepClientOpen: keepClientOpen);
    if (!res.ok || res.error.isNotFound) {
      return false;
    } else {
      return true;
    }
  }

//   // UPDATE
//   Future<LooseEntityResponse<T, S>> update<T extends DocumentResponse<S>, S,
//           R extends DocumentFields, Q extends QueryField>(
//       Documenter<T, S, R> document, List<Q> updateFields,
//       {List<String> idPath = const [],
//       bool printFields = false,
//       bool keepClientOpen = false}) async {
//     var workingPath = '${document.location.path}/${document.location.name}';
//     final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
//     if (ancestorCount != idPath.length) {
//       throw LooseException(
//           '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
//     }
//     for (final id in idPath) {
//       workingPath = workingPath.replaceFirst(dynamicNameToken, id);
//     }

//     _client ??= await _createClient();

//     var params = <String, dynamic>{
//       'currentDocument.exists': 'true',
//       'updateMask.fieldPaths':
//           updateFields.map((e) => e.name).toList(growable: false)
//     };

//     final uri = Uri(
//         scheme: 'https',
//         host: authority,
//         path: '${_database.rootPath}${workingPath}',
//         queryParameters: params);
//     final reqBody = document.toFirestoreFields();

//     if (printFields) {
//       print(json.encode(reqBody));
//     }
//     final res = await _client.patch(uri, body: json.encode(reqBody));

//     if (!keepClientOpen) {
//       done();
//     }

//     if (res.statusCode < 200 || res.statusCode > 299) {
//       return _singleEntityResponseFails<T, S>(res.statusCode, res.body);
//     }

//     final resBody = json.decode(res.body);
//     final shell = document.fromFirestore(
//         resBody['fields'] as Map<String, Object>,
//         resBody['name'] as String,
//         resBody['createTime'] as String,
//         resBody['updateTime'] as String);
//     return LooseEntityResponse(shell);
//   }

//   // DELETE
//   Future<LooseEntityResponse<T, S>>
//       delete<T extends DocumentResponse<S>, S, R extends DocumentFields>(
//           Documenter<T, S, R> document,
//           {List<String> idPath = const [],
//           bool keepClientOpen = false}) async {
//     var workingPath = '${document.location.path}/${document.location.name}';
//     final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
//     if (ancestorCount != idPath.length) {
//       throw LooseException(
//           '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
//     }
//     for (final id in idPath) {
//       workingPath = workingPath.replaceFirst(dynamicNameToken, id);
//     }

//     _client ??= await _createClient();

//     final queryParameters = <String, String>{};
//     // if (_transactionId.isNotEmpty) {
//     //   queryParameters.addAll({'transaction': _transactionId});
//     // }
//     final uri = Uri.https(
//         authority, '${_database.rootPath}${workingPath}', queryParameters);
//     final res = await _client.post(uri);
//     if (!keepClientOpen) {
//       done();
//     }
//     if (res.statusCode < 200 || res.statusCode > 299) {
//       return _singleEntityResponseFails<T, S>(res.statusCode, res.body);
//     }
//     return LooseEntityResponse(DocumentResponse.empty as T);
//   }

//   // QUERY
//   Future<LooseListResponse<T, S>>
//       _queryImpl<T extends DocumentResponse<S>, S, R extends DocumentFields>(
//           Query<T, S, R> query,
//           {bool keepClientOpen = false,
//           String transactionId = ''}) async {
//     final rawBody = query.encode();
//     final reqBody = json.encode(rawBody);

//     _client ??= await _createClient();

//     final queryParameters = <String, String>{};
//     if (transactionId.isNotEmpty) {
//       queryParameters.addAll({'transaction': transactionId});
//     }

//     final uri = Uri.https(
//         authority,
//         '${_database.rootPath}${query.document.location.pathToCollection}:runQuery',
//         queryParameters);

//     final res = await _client.post(uri, body: reqBody);
//     if (!keepClientOpen) {
//       done();
//     }
//     if (res.statusCode < 200 || res.statusCode > 299) {
//       if (res.statusCode == 400) {
//         final resBody = json.decode(res.body) as List<Object>;
//         for (final errorObject in resBody) {
//           final error = (errorObject as Map<String, Object>)['error']
//               as Map<String, Object>;
//           if ((error['status'] as String) == 'FAILED_PRECONDITION') {
//             throw LooseException((error['message'] as String));
//           } else if ((error['status'] as String) == 'INVALID_ARGUMENT') {
//             throw LooseException((error['message'] as String));
//           }
//         }
//       }
//       return LooseListResponse.fail(LooseErrors.apiCallFailed(res.body));
//     }

// //     [{
// //   "error": {
// //     "code": 400,
// //     "message": "The query requires an index. You can create it here: https://console.firebase.google.com/v1/r/project/dilawri-portal-dev/firestore/indexes?create_composite=Ck9wcm9qZWN0cy9kaWxhd3JpLXBvcnRhbC1kZXYvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZkcHMvaW5kZXhlcy9fEAEaEQoNZGVhbGVyc2hpcFJlZhABGg8KC3N0b2NrTnVtYmVyEAEaCwoHdmVyc2lvbhACGgwKCF9fbmFtZV9fEAI",
// //     "status": "FAILED_PRECONDITION"
// //   }
// // }
// // ]

// // [{
// //   "error": {
// //     "code": 400,
// //     "message": "inequality filter property and first sort order must be the same: integer and nested.innerString",
// //     "status": "INVALID_ARGUMENT"
// //   }
// // }
// // ]

// // [{
// //   "error": {
// //     "code": 400,
// //     "message": "order by clause cannot contain a field with an equality filter nested.innerString",
// //     "status": "INVALID_ARGUMENT"
// //   }
// // }

//     final decoded = json.decode(res.body);

//     // If no object contains 'document', no documents were returned
//     if (!((decoded as List)[0] as Map).containsKey('document')) {
//       return LooseListResponse(const []);
//     }
//     return LooseListResponse((decoded as List).map((e) {
//       final doc = (e as Map)['document'] as Map;

//       return query.document.fromFirestore(
//           doc['fields'] as Map<String, Object>,
//           doc['name'] as String,
//           doc['createTime'] as String,
//           doc['updateTime'] as String);
//     }).toList());
//   }

//   Future<LooseListResponse<T, S>>
//       query<T extends DocumentResponse<S>, S, R extends DocumentFields>(
//           Query<T, S, R> query,
//           {bool keepClientOpen = false}) async {
//     return _queryImpl(query, keepClientOpen: keepClientOpen);
//   }

  LooseEntityResponse<T> _singleEntityResponseFails<T>(
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

//   // TRANSACTIONS
//   Future<String> _beginTransaction() async {
//     _client ??= await _createClient();
//     final uri = Uri.https(authority, '${_database.rootPath}:beginTransaction');
//     final res = await _client.post(uri);

//     if (res.statusCode < 200 || res.statusCode > 299) {
//       // TODO: Handle failed transaction
//       return '';
//     }
//     final id =
//         (json.decode(res.body) as Map<String, Object>)['transaction'] as String;
//     return id;
//   }

//   Future<CommitResult> _commitTransaction(
//       {List<Writable> writes = const [],
//       String transactionId = '',
//       bool keepClientOpen = false}) async {
//     _client ??= await _createClient();
//     final body = {
//       'transaction': transactionId,
//       'writes': await Future.wait(writes
//           .map((e) async => (await e.encode(_database.documentRoot)))
//           .toList())
//     };
//     final uri = Uri.https(authority, '${_database.rootPath}:commit');
//     final res = await _client.post(uri, body: json.encode(body));
//     if (!keepClientOpen) {
//       done();
//     }
//     if (res.statusCode < 200 || res.statusCode > 299) {
//       // TODO: Handle failed transaction
//       print(res.statusCode);
//       print(res.body);
//       return CommitResult(WriteResults.empty, '');
//     }
//     final resBody = json.decode(res.body) as Map<String, Object>;
//     return CommitResult(
//         WriteResults(writes, resBody), resBody['commitTime'] as String);
//   }

//   Future<bool> _rollbackTransaction(String transactionId) async {
//     _client ??= await _createClient();
//     final body = json.encode({'transaction': transactionId});
//     final uri = Uri.https(authority, '${_database.rootPath}:rollback');
//     final res = await _client.post(uri, body: body);
//     if (res.statusCode < 200 || res.statusCode > 299) {
//       // TODO: Handle failed transaction
//       print(res.statusCode);
//       print(res.body);
//       return false;
//     }
//     return true;
//   }

//   // BATCH WRITE
//   Future<WriteResults> batchWrite(List<Writable> writes,
//       {bool keepClientOpen = false}) async {
//     _client ??= await _createClient();
//     final body = {
//       'writes': await Future.wait(writes
//           .map((e) async => (await e.encode(_database.documentRoot)))
//           .toList())
//     };
//     final uri = Uri.https(authority, '${_database.rootPath}:batchWrite');
//     final res = await _client.post(uri, body: json.encode(body));
//     if (!keepClientOpen) {
//       done();
//     }
//     if (res.statusCode < 200 || res.statusCode > 299) {
//       // TODO: Handle failed transaction
//       return WriteResults.empty;
//     }
//     final resBody = json.decode(res.body) as Map<String, Object>;
//     return WriteResults(writes, resBody);
//   }

//   // BATCH GET
//   Future<BatchGetResults<T, S>>
//       _batchGetImpl<T extends DocumentResponse<S>, S, R extends DocumentFields>(
//           BatchGetRequest<T, S, R> documents,
//           {bool keepClientOpen = false,
//           String transactionId = ''}) async {
//     final documentPaths = <String>[];
//     for (final idPath in documents.idPaths) {
//       var workingPath =
//           '${documents.document.location.path}/${documents.document.location.name}';

//       final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
//       if (ancestorCount != idPath.length) {
//         throw LooseException(
//             '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
//       }
//       for (final id in idPath) {
//         workingPath = workingPath.replaceFirst(dynamicNameToken, id);
//       }
//       documentPaths.add('${_database.documentRoot}${workingPath}');
//     }

//     final decoded = await _batchGetFromPaths(documentPaths,
//         transactionId: transactionId, keepClientOpen: keepClientOpen);

//     var found = <T>[];
//     var missing = <String>[];

//     decoded.forEach((e) {
//       if ((e as Map<String, Object>).containsKey('found')) {
//         final doc = (e as Map<String, Object>)['found'] as Map;
//         found.add(documents.document.fromFirestore(
//             doc['fields'] as Map<String, Object>,
//             doc['name'] as String,
//             doc['createTime'] as String,
//             doc['updateTime'] as String));
//       } else if ((e as Map<String, Object>).containsKey('missing')) {
//         missing.add((e as Map<String, Object>)['missing'] as String);
//       }
//     });

//     return BatchGetResults(LooseListResponse(found), missing);
//   }

//   // BATCH GET FROM PATHS
//   Future<List> _batchGetFromPaths(List<String> documentPaths,
//       {String transactionId = '',
//       bool keepClientOpen = false,
//       bool ownTransaction = false}) async {
//     final body = <String, Object>{'documents': documentPaths};

//     var ownTransactionId = '';
//     if (transactionId.isNotEmpty) {
//       body['transaction'] = transactionId;
//     } else if (ownTransaction) {
//       ownTransactionId = await _beginTransaction();
//       body['transaction'] = ownTransactionId;
//     }

//     _client ??= await _createClient();

//     final uri = Uri.https(authority, '${_database.rootPath}:batchGet');

//     final res = await _client.post(uri, body: json.encode(body));

//     if (ownTransactionId.isNotEmpty) {
//       final commit = await _commitTransaction(
//           transactionId: ownTransactionId, keepClientOpen: keepClientOpen);
//       if (!commit.ok) {
//         // TODO: Handle batchGet own transaction commit failure
//       }
//     }

//     if (res.statusCode < 200 || res.statusCode > 299) {
//       // TODO: Handle failed transaction
//       print('batchGet fail');
//       print(res.statusCode);
//       print(res.body);
//     }
//     return json.decode(res.body) as List;
//   }

//   // READ COUNTER
//   Future<int> _readCounterImpl(Counter counter,
//       {String transactionId = '', bool keepClientOpen = false}) async {
//     final shards = await _listFromPath(counter.location,
//         pageSize: 1000,
//         keepClientOpen: keepClientOpen,
//         transactionId: transactionId,
//         ownTransaction: transactionId.isEmpty);

//     var result = 0;

//     ((shards as Map<String, Object>)['documents'] as List).forEach((e) {
//       final fields = (e as Map<String, Object>)['fields'];
//       final field = (fields as Map<String, Object>)[counter.fieldPath];
//       final value = int.tryParse(
//           (field as Map<String, Object>)['integerValue'] as String);
//       if (value == null) {
//         return null;
//       } else {
//         result = result + value;
//       }
//     });
//     return result;
//   }

//   Future<int> readCounter(Counter counter,
//       {bool keepClientOpen = false}) async {
//     return _readCounterImpl(counter, keepClientOpen: keepClientOpen);
//   }

//   // WRITE COUNTER
//   Future writeCounter(Shard shard, {bool keepClientOpen = false}) async {
//     final write = Write.count(shard);

//     await batchWrite([write], keepClientOpen: keepClientOpen);
//   }

//   // LIST GET
//   Future<ListResults<T, S>>
//       _listImpl<T extends DocumentResponse<S>, S, R extends DocumentFields>(
//           Documenter<T, S, R> document,
//           {int pageSize = 0,
//           String nextPageToken = '',
//           bool keepClientOpen = false,
//           String transactionId = ''}) async {
//     var workingPath =
//         '${document.location.pathToCollection}${document.location.collection}';

//     final decoded = await _listFromPath(workingPath,
//         pageSize: pageSize,
//         nextPageToken: nextPageToken,
//         transactionId: transactionId,
//         keepClientOpen: keepClientOpen);

//     var docs = <T>[];
//     var resultNextPageToken = '';

//     ((decoded as Map<String, Object>)['documents'] as List).forEach((e) {
//       final doc = e as Map<String, Object>;
//       docs.add(document.fromFirestore(
//           doc['fields'] as Map<String, Object>,
//           doc['name'] as String,
//           doc['createTime'] as String,
//           doc['updateTime'] as String));
//     });
//     resultNextPageToken =
//         ((decoded as Map<String, Object>)['nextPageToken'] ?? '') as String;

//     return ListResults(LooseListResponse(docs), resultNextPageToken);
//   }

//   // LIST FROM PATH
//   Future<Map> _listFromPath(String collectionPath,
//       {String transactionId = '',
//       bool keepClientOpen = false,
//       int pageSize = 20,
//       String nextPageToken = '',
//       bool ownTransaction = false}) async {
//     final params = <String, String>{};

//     params['pageSize'] = pageSize.toString();

//     if (nextPageToken.isNotEmpty) {
//       params['nextPageToken'] = nextPageToken;
//     }

//     var ownTransactionId = '';
//     if (transactionId.isNotEmpty) {
//       params['transaction'] = transactionId;
//     } else if (ownTransaction) {
//       ownTransactionId = await _beginTransaction();
//       params['transaction'] = ownTransactionId;
//     }

//     _client ??= await _createClient();

//     final uri =
//         Uri.https(authority, '${_database.rootPath}$collectionPath', params);

//     final res = await _client.get(uri);

//     if (ownTransactionId.isNotEmpty) {
//       final commit = await _commitTransaction(
//           transactionId: ownTransactionId, keepClientOpen: keepClientOpen);
//       if (!commit.ok) {
//         // TODO: Handle batchGet own transaction commit failure
//       }
//     }

//     if (res.statusCode < 200 || res.statusCode > 299) {
//       // TODO: Handle failed transaction
//       print('batchGet fail');
//       print(res.statusCode);
//       print(res.body);
//     }
//     return json.decode(res.body) as Map;
//   }

//   Future<ListResults<T, S>>
//       list<T extends DocumentResponse<S>, S, R extends DocumentFields>(
//           Documenter<T, S, R> document,
//           {int pageSize = 20,
//           String nextPageToken = '',
//           bool keepClientOpen = false}) async {
//     return _listImpl(document,
//         pageSize: pageSize,
//         nextPageToken: nextPageToken,
//         keepClientOpen: keepClientOpen);
//   }
}
