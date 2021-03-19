import 'resource.dart';
import 'collection.dart';
import 'constants.dart';

class Document implements Resource {
  @override
  final Collection parent;
  @override
  final String name;

  const Document(this.parent, [this.name = dynamicNameToken]);

  @override
  String get path => '${parent?.path}/$name';
}
