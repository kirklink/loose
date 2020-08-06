import 'package:loose/src/resource.dart';
import 'package:loose/src/collection.dart';
import 'package:loose/src/constants.dart';

class Document extends Resource {
  const Document(Collection parent, [String name = dynamicNameToken]) : super(parent, name);
  
}
