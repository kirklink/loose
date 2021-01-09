import 'constants.dart';

class FirestoreDatabase {
  final String project;
  final String database;
  const FirestoreDatabase(this.project, [this.database = '(default)']);
  String get rootPath =>
      '/$apiVersion/projects/$project/databases/$database/documents';
  String get documentRoot => 'projects/$project/databases/$database/documents';
}
