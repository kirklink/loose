import 'resource.dart';
import 'collection.dart';
import 'constants.dart';

class Document extends Resource {
  const Document(Collection parent, [String name = dynamicNameToken])
      : super(parent, name);
}
