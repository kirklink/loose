import 'dart:convert' show json;

import 'package:googleapis_auth/auth_io.dart' as auth;
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





abstract class LooseErrors {
  static const documentExists = LooseError(409, 'Document already exists');
  // static const notFound = LooseError(1, 'Document not found');
  static const apiCallFailed = LooseError(500, 'Call to Firestore failed.');
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

  Reference reference(Documenter document, [String name = '']) {
    return Reference(document, _database, name);
  }


  // CREATE
  Future<LooseResponse<T, S>>
      create<T extends DocumentShell<S>, S, R extends QueryFields>(
          Documenter<T, S, R> document,
          {List<String> idPath = const []}) async {
    if (document.location.name == dynamicNameToken && idPath.isEmpty) {
      throw LooseException(
          'A name is required for this document but was not provided in idPath.');
    }

    var docId = '';
    if (document.location.name == dynamicNameToken) {
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
    final res = await _client.post(uri, body: json.encode(reqBody));
    if (res.statusCode < 200 || res.statusCode > 299) {
      return LooseResponse.fail(LooseErrors.apiCallFailed);
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

    final res = await _client.post(uri);
    if (res.statusCode == 409) {
      return LooseResponse.fail(LooseErrors.documentExists);
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

    final uri =
        Uri.https(authority, '${_database.rootPath}${document.location.path}');
    final reqBody = document.toFirestoreFields();
    final res = await _client.post(uri, body: json.encode(reqBody));
    if (res.statusCode < 200 || res.statusCode > 299) {
      return LooseResponse.fail(LooseErrors.apiCallFailed);
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
      return LooseResponse.fail(LooseErrors.apiCallFailed);
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
      return LooseResponse.fail(LooseErrors.apiCallFailed);
    }

    final decoded = json.decode(res.body);

    // If no object contains 'document', no documents were returned
    if (!((decoded as List)[0] as Map).containsKey('document')) {
      return LooseResponse.list(const []);
    }
    return LooseResponse.list(
        (decoded as List).map((e) {
          final doc = (e as Map)['document'] as Map;

          return query.document.fromFirestore(
              doc['fields'] as Map<String, Object>,
              doc['name'] as String,
              doc['createTime'] as String,
              doc['updateTime'] as String);
        }).toList());
  }

  void done() {
    _client.close();
  }
}
