import 'package:path/path.dart' as p;


class DocumentInfo {
  final String name;
  final String collection;
  final String pathToCollection;
  const DocumentInfo(this.name, this.collection, this.pathToCollection);
  String get path {
    final context = p.Context(style: p.Style.url);
    return context.join(pathToCollection, collection);
  }
}