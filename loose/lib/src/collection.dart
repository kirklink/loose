import 'resource.dart';
import 'document.dart';

class Collection implements Resource {
  @override
  final Document parent;
  @override
  final String id;

  const Collection(this.parent, this.id);
  const Collection.root(this.id, [this.parent]);

  bool get isAtRoot => parent == null;

  @override
  String get path => '${parent?.path ?? ""}/$id';
}
