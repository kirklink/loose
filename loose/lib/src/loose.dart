import 'dart:convert' show json;

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:loose/schema.dart';
// import 'package:googleapis/firestore/v1.dart' as fs;

import 'package:loose/src/loose_credentials.dart';
import 'package:loose/src/documenter.dart';
import 'package:loose/src/document_shell.dart';
import 'package:loose/src/loose_response.dart';
import 'package:loose/src/reference.dart';
import 'package:loose/src/firestore_database.dart';
import 'package:loose/src/constants.dart';
import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/query/query.dart';

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

  Future _createClient() async {
    if (_creds.fromApplicationDefault) {
      _client =
          await auth.clientViaApplicationDefaultCredentials(scopes: _SCOPES);
    } else {
      final jsonCreds = auth.ServiceAccountCredentials.fromJson({
        'private_key_id': _creds.privateKeyId,
        'private_key': _creds.privateKey,
        'client_email': _creds.clientEmail,
        'client_id': _creds.clientId,
        'type': _creds.type
      });
      _client = await auth.clientViaServiceAccount(jsonCreds, _SCOPES);
    }
  }

  Reference reference(Documenter document, {List<String> idPath = const []}) {
    return Reference(document, _database, idPath: idPath);
  }

  // CREATE
  Future<LooseResponse<T, S>>
      create<T extends DocumentShell<S>, S, R extends QueryFields>(
          Documenter<T, S, R> document,
          {List<String> idPath = const [],
          bool autoAssignId = false,
          bool printFields = false}) async {
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

    if (_client == null) {
      await _createClient();
    }

    Uri uri;
    if (docId.isNotEmpty) {
      uri = Uri.https(authority, '${_database.rootPath}${workingPath}',
          {'documentId': docId});
    } else {
      uri = Uri.https(
          authority, '${_database.rootPath}${document.location.path}');
    }

    final reqBody = document.toFirestoreFields();
    if (printFields) {
      print(json.encode(reqBody));
    }
    final res = await _client.post(uri, body: json.encode(reqBody));

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
          Documenter<T, S, R> document,
          {List<String> idPath = const []}) async {
    var workingPath = '${document.location.path}/${document.location.name}';

    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
    if (ancestorCount != idPath.length) {
      throw LooseException(
          '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    if (_client == null) {
      await _createClient();
    }

    final uri = Uri.https(authority, '${_database.rootPath}${workingPath}');

    final res = await _client.get(uri);

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

  // UPDATE
  Future<LooseResponse<T, S>>
      update<T extends DocumentShell<S>, S, R extends QueryFields>(
          Documenter<T, S, R> document,
          {List<String> idPath = const [],
          bool printFields = false}) async {
    var workingPath = '${document.location.path}/${document.location.name}';
    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
    if (ancestorCount != idPath.length) {
      throw LooseException(
          '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    if (_client == null) {
      await _createClient();
    }

    final uri =
        Uri.https(authority, '${_database.rootPath}${document.location.path}');
    final reqBody = document.toFirestoreFields();
    if (printFields) {
      print(json.encode(reqBody));
    }
    final res = await _client.post(uri, body: json.encode(reqBody));

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
          {List<String> idPath = const []}) async {
    var workingPath = '${document.location.path}/${document.location.name}';
    final ancestorCount = workingPath.split(dynamicNameToken).length - 1;
    if (ancestorCount != idPath.length) {
      throw LooseException(
          '${idPath.length} document ids were provided. $ancestorCount required in $workingPath');
    }
    for (final id in idPath) {
      workingPath = workingPath.replaceFirst(dynamicNameToken, id);
    }

    if (_client == null) {
      await _createClient();
    }
    final uri = Uri.https(authority, '${_database.rootPath}${workingPath}');
    final res = await _client.post(uri);
    if (res.statusCode < 200 || res.statusCode > 299) {
      return _singleEntityResponseFails<T, S>(res.statusCode, res.body);
    }
    return LooseResponse.single(DocumentShell.empty as T);
  }

  // QUERY
  Future<LooseResponse<T, S>>
      query<T extends DocumentShell<S>, S, R extends QueryFields>(
          Query<T, S, R> query) async {
    final rawBody = query.encode;
    final reqBody = json.encode(rawBody);

    if (_client == null) {
      await _createClient();
    }

    final uri = Uri.https(authority,
        '${_database.rootPath}${query.document.location.pathToCollection}:runQuery');

    final res = await _client.post(uri, body: reqBody);
    if (res.statusCode < 200 || res.statusCode > 299) {
      if (res.statusCode == 400) {
        final resBody = json.decode(res.body) as List<Map<String, Object>>;
        for (final errorObject in resBody) {
          final error = errorObject['error'] as Map<String, Object>;
          if ((error['message'] as String)
              .startsWith('The query requires an index.')) {
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

  void done() {
    _client.close();
  }
}
