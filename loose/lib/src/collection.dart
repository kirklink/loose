// import 'package:loose/annotations.dart';
import 'resource.dart';
import 'document.dart';

class Collection implements Resource {
  @override
  final Document parent;
  @override
  final String name;

  const Collection(this.parent, this.name);
  const Collection.root(this.name, [this.parent]);

  bool get isAtRoot => parent == null;

  @override
  String get path => '${parent?.path ?? ""}/$name';
}
