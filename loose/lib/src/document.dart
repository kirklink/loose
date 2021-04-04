import 'loose_exception.dart';
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
  String get path => '${parent.path}/$id';

  bool canResolvePath(List<String> idPath, [bool dynamicId = false]) {
    final tokenCount = dynamicNameToken.allMatches(path).length;
    final extra = dynamicId ? 1 : 0;
    return tokenCount == idPath.length + extra;
  }

  String resolvePath(List<String> idPath, [bool dynamicId = false]) {
    final tokenCount = dynamicNameToken.allMatches(path).length;
    final extra = dynamicId ? 1 : 0;
    if (tokenCount != idPath.length + extra) {
      throw LooseException(
          '${idPath.length} ids provided and $tokenCount are required.');
    }
    var _workingPath = path;
    for (final id in idPath) {
      _workingPath = _workingPath.replaceFirst(dynamicNameToken, id);
    }
    return _workingPath;
  }
}
