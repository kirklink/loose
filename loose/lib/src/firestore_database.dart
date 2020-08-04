class FirestoreDatabase {
  final String project;
  final String database;
  const FirestoreDatabase(this.project, [this.database = '(default)']);
  String get rootPath => 'projects/$project/databases/$database/documents';
}