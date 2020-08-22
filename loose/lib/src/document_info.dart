class DocumentInfo {
  final String name;
  final String collection;
  final String pathToCollection;
  const DocumentInfo(this.name, this.collection, this.pathToCollection);
  String get path {
    if (pathToCollection == '/') {
      return '/$collection'; 
    } else {
      return '/$pathToCollection/$collection';
    }
  }
}