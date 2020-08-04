// import 'package:loose/annotations.dart';
import 'package:loose/src/resource.dart';
import 'package:loose/src/document.dart';

class Collection extends Resource {
  const Collection(Document parent, String name) : super(parent, name);
  const Collection.root(String name) : super.root(name);
}
