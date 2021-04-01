import 'resource.dart';
import 'collection.dart';
import 'constants.dart';

class Document implements Resource {
  @override
  final Collection parent;
  @override
  final String id;

  const Document(this.parent, [this.id = dynamicNameToken]);

  @override
  String get path => '${parent?.path}/$id';
}
