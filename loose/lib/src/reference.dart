import 'package:loose/src/document_request.dart';

import 'document_request.dart';
import 'firestore_database.dart';
import 'loose_exception.dart';

class Reference {
  final String name;

  const Reference._(this.name);

  factory Reference(DocumentRequest request, FirestoreDatabase database,
      {List<String> idPath = const []}) {
    String workingPath;
    try {
      workingPath = request.document.resolvePath(idPath);
    } on LooseException catch (_) {
      throw LooseException('Could not resolve reference path.');
    }
    return Reference._('${database.documentRoot}$workingPath');
  }

  const Reference.fromString(String reference) : name = reference;

  bool get isRoot => name == '/';

  List<String> get idPath {
    const token = '/(default)/documents/';
    if (token.allMatches(name).length > 1) {
      return const [];
    }
    final split = name.split(token);
    if (split.isEmpty) {
      return const [];
    } else {
      final l = split[1].split('/').asMap();
      final m = Map.of(l)..removeWhere((k, v) => k.isEven);
      final r = m.values.toList();
      return r;
    }
  }

  bool matchesString(String string) => name == string;

  @override
  String toString() => name;

  @override
  bool operator ==(covariant Reference other) {
    return name == other.name;
  }

  @override
  int get hashCode => name.hashCode;
}
