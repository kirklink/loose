import 'dart:convert' show json;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/firestore/v1.dart' as fs;

import 'package:loose/src/loose_credentials.dart';
import 'package:loose/src/documenter.dart';
import 'package:loose/src/document_shell.dart';
import 'package:loose/src/loose_response.dart';
import 'package:loose/src/reference.dart';
import 'package:loose/src/firestore_database.dart';
import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/query/query.dart';

class Loose {

  final _SCOPES = const [fs.FirestoreApi.CloudPlatformScope, fs.FirestoreApi.DatastoreScope];
  
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
      _client = await auth.clientViaApplicationDefaultCredentials(scopes: _SCOPES);
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

  Future<LooseResponse<T, S>> read<T extends DocumentShell<S>, S, R extends QueryFields>(Documenter<T, S, R> document, String id) async {
    if (document.location.name == '@' && id.isEmpty) {
      throw LooseException('An id should be provided for the document at ${document.location}');
    }
    if (document.location.name != '@' && id.isNotEmpty) {
      throw LooseException('An id should not be provided for the document ${document.location}');
    }
    final pathEnd = document.location.name == '@' ? id : document.location.name;
    if (_client == null) {
      await _createClient();
    }
    // final separator = document.location.path.isEmpty ? '' : '/';
    final f = fs.FirestoreApi(_client);
    final path = '${_database.rootPath}${document.location.path}/$pathEnd';
    print(path);
    final fsdoc = await f.projects.databases.documents.get(path);
    final shell = document.fromFirestore(fsdoc.fields, fsdoc.name, fsdoc.createTime, fsdoc.updateTime);
    return LooseResponse.single(shell, true);
  }

  Future<LooseResponse<T, S>> create<T extends DocumentShell<S>, S, R extends QueryFields>(Documenter<T, S, R> document, [String id = '']) async {
    if (document.location.name != '@' && id.isNotEmpty) {
      throw LooseException('An id should not be provided for the document at ${document.location.pathToCollection}${document.location.collection}/');
    }
    final docId = document.location.name != '@' ? document.location.name : id.isNotEmpty ? id : null;
    if (_client == null) {
      await _createClient();
    }
    final f = fs.FirestoreApi(_client);
    final newdoc = fs.Document()..fields = document.toFirestoreFields();
    final pathEnd = document.location.pathToCollection == '/' ? '' : document.location.pathToCollection;
    print('${_database.rootPath}${pathEnd}');
    print('${document.location.collection}');
    final fsdoc = await f.projects.databases.documents.createDocument(
      newdoc,
      '${_database.rootPath}${pathEnd}',
      '${document.location.collection}',
      documentId: docId
    );
    final shell = document.fromFirestore(fsdoc.fields, fsdoc.name, fsdoc.createTime, fsdoc.updateTime);
    return LooseResponse.single(shell, true);
  }


  Future<LooseResponse<T, S>> update<T extends DocumentShell<S>, S, R extends QueryFields>(Documenter<T, S, R> document, [String id = '']) async {
    if (document.location.name != '@' && id.isNotEmpty) {
      throw LooseException('An id should not be provided for the document at ${document.location.pathToCollection}/${document.location.collection}/');
    }
    final docId = document.location.name != '@' ? document.location.name : id.isNotEmpty ? id : null;
    if (_client == null) {
      await _createClient();
    }
    final f = fs.FirestoreApi(_client);
    final updateDoc = fs.Document()..fields = document.toFirestoreFields();
    final fsdoc = await f.projects.databases.documents.patch(
      updateDoc,
      '${_database.rootPath}${document.location.path}/$docId'
    );
    final shell = document.fromFirestore(fsdoc.fields, fsdoc.name, fsdoc.createTime, fsdoc.updateTime);
    return LooseResponse.single(shell, true);
  }


  Future<LooseResponse<T, S>> delete<T extends DocumentShell<S>, S, R extends QueryFields>(Documenter<T, S, R> document, [String id = '']) async {
    if (document.location.name != '@' && id.isNotEmpty) {
      throw LooseException('An id should not be provided for the document at ${document.location.pathToCollection}${document.location.collection}/');
    }
    final docId = document.location.name != '@' ? document.location.name : id.isNotEmpty ? id : null;
    if (_client == null) {
      await _createClient();
    }
    final f = fs.FirestoreApi(_client);
    await f.projects.databases.documents.delete(
      '${_database.rootPath}${document.location.path}/$docId'
    );
    return LooseResponse.single(DocumentShell.empty as T, true);
  }
  
  // 409 Already exists
  Future<LooseResponse<T, S>> query<T extends DocumentShell<S>, S, R extends QueryFields>(Query<T, S, R> query) async {
    final rawBody = query.result;
    final body = json.encode(rawBody);
    print(body);
    if (_client == null) {
      await _createClient();
    }
    http.Response resp;
    try {
      resp = await _client.post('https://firestore.googleapis.com/v1/${_database.rootPath}${query.document.location.pathToCollection}:runQuery', body: body);
    } catch (e) {
      return LooseResponse.list(const [], false, 1);
    }
    
    final decoded = json.decode(resp.body);
    print(decoded);
    if (!((decoded as List)[0] as Map).containsKey('document')) {
      return LooseResponse.list(const [], true);
    }
    return LooseResponse.list((decoded as List).map((e) {
      final doc = fs.Document.fromJson((e as Map)['document'] as Map);
      // print(doc.toJson());
      return query.document.fromFirestore(doc.fields, doc.name, doc.createTime, doc.updateTime);
    }).toList(), true);
  }

  void done() {
    _client.close();
  }
}

