import 'package:loose/src/resource.dart';
import 'package:loose/src/collection.dart';

class Document extends Resource {
  const Document(Collection parent, [String name = '@']) : super(parent, name);
  
}
