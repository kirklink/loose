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

  const Reference.empty() : name = '';

  Reference.fromFirestore(Map<String, Object> reference,
      [String defaultValue = ''])
      : name = reference['referenceValue'] as String? ?? defaultValue;

  bool get isEmpty => name.isEmpty;

  List<String> get idPath {
    const token = '/(default)/documents/';
    if (token.allMatches(name).length > 1) {
      return const [];
    }
    final split = name.split(token);
    if (split.isEmpty) {
      return const [];
    } else {
      return (Map.of(split[1].split('/').asMap())
            ..removeWhere((k, v) => k.isEven))
          .values
          .toList();
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
